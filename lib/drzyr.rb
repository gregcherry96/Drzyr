# frozen_string_literal: true

# lib/drzyr.rb
require 'sinatra/base'
require 'faye/websocket'
require 'json'
require 'erb'
require 'securerandom'
require 'date'

# A lightweight framework for creating interactive web UIs with Ruby.
module Drzyr
  # --- Constants for WebSocket communication ---
  MSG_TYPE_RENDER = 'render'
  MSG_TYPE_CLIENT_READY = 'client_ready'
  MSG_TYPE_NAVIGATE = 'navigate'
  MSG_TYPE_UPDATE = 'update'
  MSG_TYPE_BUTTON_PRESS = 'button_press'

  # Manages the application's state.
  class StateManager
    attr_reader :connections, :pages, :state, :pending_button_presses, :lock

    def initialize
      @connections = {}
      @pages = {}
      @state = Hash.new { |h, k| h[k] = {} }
      @pending_button_presses = Hash.new { |h, k| h[k] = {} }
      @lock = Mutex.new # Protects shared state in multi-threaded environments
    end

    def synchronized(&block)
      @lock.synchronize(&block)
    end
  end

  # --- Public API ---
  module_function

  def state
    @state ||= StateManager.new
  end

  def page(path, &block)
    state.pages[path] = block
  end

  def run
    yield if block_given?
    state.pages.each_key do |path|
      Server.get(path) { erb :index }
    end
    Server.run!(port: 4567)
  end

  # --- Internal Logic & UI Building ---

  class TabBuilder
    attr_reader :tabs_content, :tab_labels

    def initialize(ui_builder)
      @ui_builder = ui_builder
      @tabs_content = {}
      @tab_labels = []
    end

    def tab(label, &block)
      @tab_labels << label
      @tabs_content[label] = @ui_builder.capture_elements(&block)
    end
  end

  class ColumnBuilder
    attr_reader :columns

    def initialize(ui_builder)
      @ui_builder = ui_builder
      @columns = []
    end

    def column(&block)
      @columns << @ui_builder.capture_elements(&block)
    end
  end

  # Dynamically builds the UI by executing a page block in its context.
  class UIBuilder
    attr_reader :ui_elements

    def initialize(page_state, pending_presses)
      @page_state = page_state
      @pending_presses = pending_presses
      @ui_elements = []
    end

    (1..6).each { |l| define_method("h#{l}") { |text| add_element("heading#{l}", text: text) } }
    def p(text)
      add_element('paragraph', text: text)
    end

    def table(data, headers: [])
      add_element('table', data: data, headers: headers)
    end

    def alert(text, style: :primary)
      add_element('alert', text: text, style: style)
    end

    def image(src, caption: nil)
      add_element('image', src: src, caption: caption)
    end

    def code(text, language: nil)
      add_element('code', text: text, language: language)
    end

    def latex(text)
      add_element('latex', text: text)
    end

    def spinner(label: nil)
      add_element('spinner', label: label)
    end

    def divider
      add_element('divider', {})
    end

    def expander(label:, expanded: false, &block)
      expander_id = "expander_#{label.gsub(/\s+/, '_').downcase}"
      is_expanded = @page_state.fetch(expander_id, expanded)

      if @pending_presses.delete(expander_id)
        is_expanded = !is_expanded
        @page_state[expander_id] = is_expanded
      end

      content = is_expanded ? capture_elements(&block) : []
      add_element('expander', id: expander_id, label: label, expanded: is_expanded, content: content)
    end

    def form_group(label:, &block)
      content = capture_elements(&block)
      add_element('form_group', label: label, content: content)
    end

    def button(id:, text:)
      add_element('button', id: id, text: text)
      @pending_presses.delete(id)
    end

    def slider(id:, label:, min:, max:, step: 1, default: nil, error: nil)
      value = @page_state.fetch(id, default || min).to_f
      add_input_element('slider', id, label, value.to_s, error: error, min: min, max: max, step: step)
      value
    end

    def text_input(id:, label:, default: '', error: nil)
      value = @page_state.fetch(id, default)
      add_input_element('text_input', id, label, value, error: error)
    end

    def number_input(id:, label:, default: 0, error: nil)
      value = @page_state.fetch(id, default)
      numeric_value = value.to_s.include?('.') ? value.to_f : value.to_i
      add_input_element('number_input', id, label, value.to_s, error: error)
      numeric_value
    end

    def password_input(id:, label:, default: '', error: nil)
      value = @page_state.fetch(id, default)
      add_input_element('password_input', id, label, value, error: error)
    end

    def date_input(id:, label:, default: nil, error: nil)
      default_str = default || Date.today.to_s
      value_str = @page_state.fetch(id, default_str)
      add_input_element('date_input', id, label, value_str, error: error)
      begin
        Date.parse(value_str)
      rescue StandardError
        Date.parse(default_str)
      end
    end

    def checkbox(id:, label:, error: nil)
      value = @page_state.fetch(id, false)
      add_input_element('checkbox', id, label, value, error: error)
    end

    def selectbox(id:, label:, options:, error: nil)
      value = @page_state.fetch(id, options.first)
      add_input_element('selectbox', id, label, value, error: error, options: options)
    end

    def textarea(id:, label:, default: '', rows: 3, error: nil)
      value = @page_state.fetch(id, default)
      add_input_element('textarea', id, label, value, error: error, rows: rows)
      value
    end

    def multi_select(id:, label:, options:, default: [], error: nil)
      value = @page_state.fetch(id, default)
      current_selection = value.is_a?(Array) ? value : value.to_s.split(',')
      add_input_element('multi_select', id, label, current_selection, error: error, options: options)
      current_selection
    end

    def radio_group(id:, label:, options:, default: nil, error: nil)
      default_value = default || options.first
      value = @page_state.fetch(id, default_value)
      add_input_element('radio_group', id, label, value, error: error, options: options)
      value
    end

    def tabs
      tab_builder = TabBuilder.new(self)
      yield tab_builder

      tabs_id = "tabs_#{tab_builder.tab_labels.join.hash.abs}"
      active_tab = @page_state.fetch(tabs_id, tab_builder.tab_labels.first)

      tab_builder.tab_labels.each do |label|
        tab_button_id = "#{tabs_id}_#{label}"
        if @pending_presses.delete(tab_button_id)
          active_tab = label
          @page_state[tabs_id] = active_tab
        end
      end

      add_element('tabs',
                  id: tabs_id,
                  labels: tab_builder.tab_labels,
                  active_tab: active_tab,
                  content: tab_builder.tabs_content[active_tab])
    end

    def columns
      builder = ColumnBuilder.new(self)
      yield builder
      add_element('columns_container', columns: builder.columns)
    end

    def capture_elements(&block)
      original_elements = @ui_elements
      @ui_elements = []
      instance_exec(&block)
      captured = @ui_elements
      @ui_elements = original_elements
      captured
    end

    private

    def add_element(type, attributes)
      @ui_elements << attributes.merge(type: type)
    end

    def add_input_element(type, id, label, value, error: nil, **attrs)
      add_element(type, { id: id, label: label, value: value, error: error, **attrs })
      value
    end
  end

  def rerun_page(path, ws)
    page_block = state.pages[path]
    return [] unless page_block

    elements = nil
    state.synchronized do
      page_state = state.state[path]
      pending_presses_for_ws = state.pending_button_presses.fetch(ws, {})

      builder = UIBuilder.new(page_state, pending_presses_for_ws)
      builder.instance_exec(&page_block)
      elements = builder.ui_elements

      state.pending_button_presses.delete(ws)
    end
    elements
  end

  # --- Sinatra Web Server ---
  class Server < Sinatra::Base
    set :public_folder, File.expand_path('public', __dir__)
    set :views, File.expand_path('public', __dir__)

    get '/websocket' do
      halt(400) unless Faye::WebSocket.websocket?(request.env)
      ws = Faye::WebSocket.new(request.env)

      ws.on :open do
        Drzyr.state.synchronized { Drzyr.state.connections[ws] = nil }
      end

      ws.on :message do |event|
        data = JSON.parse(event.data)
        path = data['path']
        Drzyr.state.synchronized { Drzyr.state.connections[ws] ||= path } if path
        handle_message(data, path, ws) if path
      end

      ws.on :close do
        Drzyr.state.synchronized do
          Drzyr.state.connections.delete(ws)
          Drzyr.state.pending_button_presses.delete(ws)
        end
        ws = nil
      end
      ws.rack_response
    end

    private

    def handle_message(data, path, ws)
      app_state = Drzyr.state
      app_state.synchronized do
        case data['type']
        when MSG_TYPE_UPDATE
          app_state.state[path][data['widget_id']] = data['value']
        when MSG_TYPE_BUTTON_PRESS
          app_state.pending_button_presses[ws] ||= {}
          app_state.pending_button_presses[ws][data['widget_id']] = true
        end
      end

      elements = Drzyr.rerun_page(path, ws)
      ws&.send({ type: MSG_TYPE_RENDER, elements: elements }.to_json)
    end
  end
end
