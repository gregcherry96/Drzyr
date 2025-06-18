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
  MSG_TYPE_RENDER = 'render'.freeze
  MSG_TYPE_CLIENT_READY = 'client_ready'.freeze
  MSG_TYPE_NAVIGATE = 'navigate'.freeze
  MSG_TYPE_UPDATE = 'update'.freeze
  MSG_TYPE_BUTTON_PRESS = 'button_press'.freeze

  # Manages the application's state.
  class StateManager
    attr_accessor :connections, :pages, :state, :pending_button_presses

    def initialize
      @connections = {}
      @pages = {}
      @state = Hash.new { |h, k| h[k] = {} }
      @pending_button_presses = Hash.new { |h, k| h[k] = {} }
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

  # Helper class for the `columns` layout component.
  class ColumnBuilder
    attr_reader :columns

    def initialize(ui_builder)
      @ui_builder = ui_builder
      @columns = []
    end

    def column(&block)
      # Use the main UIBuilder to capture elements created inside the block
      column_elements = @ui_builder.capture_elements(&block)
      @columns << column_elements
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

    # --- Start of Public DSL Methods ---

    (1..6).each do |level|
      define_method("h#{level}") { |text| add_element("heading#{level}", text: text) }
    end

    def p(text)
      add_element('paragraph', text: text)
    end

    def table(data, headers: [])
      add_element('table', data: data, headers: headers)
    end

    def button(id:, text:)
      add_element('button', id: id, text: text)
      @pending_presses.delete(id) || false
    end

    def slider(id:, label:, min:, max:, step: 1, default: nil)
      value = @page_state[id] || default || min
      add_input_element('slider', id, label, value.to_s, min: min, max: max, step: step)
      value.to_f
    end

    def text_input(id:, label:, default: '')
      value = @page_state.fetch(id, default)
      add_input_element('text_input', id, label, value)
    end

    def number_input(id:, label:, default: 0)
      value = @page_state.fetch(id, default)
      add_input_element('number_input', id, label, value.to_s)
    end

    def password_input(id:, label:, default: '')
      value = @page_state.fetch(id, default)
      add_input_element('password_input', id, label, value)
    end

    def date_input(id:, label:, default: Date.today.to_s)
      value = @page_state.fetch(id, default)
      add_input_element('date_input', id, label, value)
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

    # --- Start of Public Helper Methods ---

    def capture_elements(&block)
      original_elements = @ui_elements
      @ui_elements = []
      instance_exec(&block)
      captured = @ui_elements
      @ui_elements = original_elements
      captured
    end

    # --- Start of Private Methods ---
    private

    def add_element(type, attributes)
      @ui_elements << attributes.merge(type: type)
    end

    def add_input_element(type, id, label, value, **extra_attrs)
      attributes = { id: id, label: label, value: value, **extra_attrs }
      add_element(type, attributes)
      value
    end
  end

  def rerun_page(path, ws)
    page_block = state.pages[path]
    return [] unless page_block

    page_state = state.state[path]
    pending_presses = state.pending_button_presses.fetch(ws, {})

    builder = UIBuilder.new(page_state, pending_presses)
    builder.instance_exec(&page_block)
    builder.ui_elements
  end

  # --- Sinatra Web Server ---

  class Server < Sinatra::Base
    set :public_folder, File.expand_path('public', __dir__)
    set :views, File.expand_path('public', __dir__)

    get '/websocket' do
      halt(400, 'Invalid request') unless Faye::WebSocket.websocket?(request.env)

      ws = Faye::WebSocket.new(request.env)

      ws.on :message do |event|
        data = JSON.parse(event.data)
        path = data['path']
        Drzyr.state.connections[ws] = path
        handle_message(data, path, ws)
      end

      ws.on :close do |_event|
        Drzyr.state.connections.delete(ws)
        Drzyr.state.pending_button_presses.delete(ws)
        ws = nil
      end

      ws.rack_response
    end

    private

    def handle_message(data, path, ws)
      app_state = Drzyr.state
      msg_type = data['type']
      widget_id = data['widget_id']

      case msg_type
      when MSG_TYPE_UPDATE
        app_state.state[path][widget_id] = data['value']
      when MSG_TYPE_BUTTON_PRESS
        app_state.pending_button_presses[ws][widget_id] = true
      end

      if [MSG_TYPE_CLIENT_READY, MSG_TYPE_NAVIGATE, MSG_TYPE_UPDATE, MSG_TYPE_BUTTON_PRESS].include?(msg_type)
        elements = Drzyr.rerun_page(path, ws)
        ws.send({ type: MSG_TYPE_RENDER, elements: elements }.to_json)
      end
    end
  end
end
