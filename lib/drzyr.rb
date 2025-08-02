# lib/drzyr.rb
require 'sinatra/base'
require 'faye/websocket'
require 'json'
require 'erb'
require 'securerandom'
require 'date'
require 'thread' # For Mutex

# A lightweight framework for creating interactive web UIs with Ruby.
module Drzyr
  # --- Constants for WebSocket communication ---
  MSG_TYPE_RENDER = 'render'.freeze
  MSG_TYPE_CLIENT_READY = 'client_ready'.freeze
  MSG_TYPE_NAVIGATE = 'navigate'.freeze
  MSG_TYPE_UPDATE = 'update'.freeze
  MSG_TYPE_BUTTON_PRESS = 'button_press'.freeze

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
    def p(text); add_element('paragraph', text: text); end
    def table(data, headers: []); add_element('table', data: data, headers: headers); end

    def button(id:, text:)
      add_element('button', id: id, text: text)
      # Atomically check for and remove the pending press for this specific button.
      # This ensures the button press is consumed only once and doesn't affect other components.
      @pending_presses.delete(id)
    end

    def slider(id:, label:, min:, max:, step: 1, default: nil)
      value = @page_state.fetch(id, default || min).to_f
      add_input_element('slider', id, label, value.to_s, min: min, max: max, step: step)
      value
    end

    def text_input(id:, label:, default: '')
      value = @page_state.fetch(id, default)
      add_input_element('text_input', id, label, value)
    end

    def number_input(id:, label:, default: 0)
      value = @page_state.fetch(id, default)
      numeric_value = value.to_s.include?('.') ? value.to_f : value.to_i
      add_input_element('number_input', id, label, value.to_s)
      numeric_value
    end

    def password_input(id:, label:, default: '')
      value = @page_state.fetch(id, default)
      add_input_element('password_input', id, label, value)
    end

    def date_input(id:, label:, default: nil)
      default_str = default || Date.today.to_s
      value_str = @page_state.fetch(id, default_str)
      add_input_element('date_input', id, label, value_str)
      Date.parse(value_str) rescue Date.parse(default_str)
    end

    def checkbox(id:, label:)
      value = @page_state.fetch(id, false)
      add_input_element('checkbox', id, label, value)
    end

    def selectbox(id:, label:, options:)
      value = @page_state.fetch(id, options.first)
      add_input_element('selectbox', id, label, value, options: options)
    end

    def columns(&block)
      builder = ColumnBuilder.new(self)
      yield builder
      add_element('columns_container', columns: builder.columns)
    end

    def capture_elements(&block)
      original_elements, @ui_elements = @ui_elements, []
      instance_exec(&block)
      captured, @ui_elements = @ui_elements, original_elements
      captured
    end

    private
    def add_element(type, attributes); @ui_elements << attributes.merge(type: type); end
    def add_input_element(type, id, label, value, **attrs); add_element(type, {id:id, label:label, value:value, **attrs}); value; end
  end

  def rerun_page(path, ws)
    page_block = state.pages[path]
    return [] unless page_block

    page_state, pending_presses = nil, nil
    state.synchronized do
      page_state = state.state[path]
      # Crucially, we fetch a *copy* of the pending presses for this specific run.
      pending_presses = state.pending_button_presses.fetch(ws, {}).dup
    end

    builder = UIBuilder.new(page_state, pending_presses)
    builder.instance_exec(&page_block)
    builder.ui_elements
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
          # Ensure the hash for the websocket connection exists
          app_state.pending_button_presses[ws] ||= {}
          app_state.pending_button_presses[ws][data['widget_id']] = true
        end
      end

      elements = Drzyr.rerun_page(path, ws)
      ws.send({ type: MSG_TYPE_RENDER, elements: elements }.to_json) if ws
    end
  end
end
