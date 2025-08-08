# frozen_string_literal: true

require 'mustache'

# The main module for the Drzyr framework, containing the core server logic
# and state management for building interactive web applications.
module Drzyr
  @state_lock = Mutex.new

  def self.state
    @state ||= StateManager.new
  end

  def self.register_page(path, type, &block)
    state.pages[path] = { type: type, block: block }
  end

  def self.rerun_page(path, websocket, session_id)
    page_block = find_page_block(path)
    return {} unless page_block

    execute_page_build(page_block, path, websocket, session_id)
  end

  def self.build_ui_for_page(page_block, session_id, path, websocket)
    session_entry = state.state[session_id]
    pending_presses = state.synchronized { state.pending_button_presses.fetch(websocket, {}).dup }

    session_entry[:lock].synchronize do
      build_elements(page_block, session_entry[:data][path], pending_presses)
    end
  end

  # The main Roda application class that handles HTTP requests and WebSocket connections.
  class Server < Roda
    plugin :public, root: File.expand_path('../public', __dir__)

    route do |request|
      request.public

      request.on 'websocket' do
        handle_websocket(request)
      end

      page_config = Drzyr.state.pages[request.path]
      if page_config
        render_page(page_config)
      else
        response.status = 404
        '<h1>404 Not Found</h1><p>The page you requested could not be found.</p>'
      end
    end

    private

    # --- Websocket Connection Handlers ---

    def handle_websocket(request)
      halt(400) unless Faye::WebSocket.websocket?(request.env)
      websocket = Faye::WebSocket.new(request.env)

      websocket.on(:open) { setup_new_session(websocket) }
      websocket.on(:message) { |event| process_message(websocket, event) }
      websocket.on(:close) { cleanup_session(websocket) }

      request.halt(websocket.rack_response)
    end

    def setup_new_session(websocket)
      Drzyr.state.synchronized do
        session_id = SecureRandom.hex(16)
        Drzyr.state.connections[websocket] = { session_id: session_id, path: nil }
        Drzyr.state.state[session_id] # This initializes the session state with its lock
        Drzyr::Logger.info "New connection opened with session ID: #{session_id}"
      end
    end

    def process_message(websocket, event)
      data = JSON.parse(event.data)
      path = data['path']
      session_id = nil

      Drzyr.state.synchronized do
        conn_info = Drzyr.state.connections[websocket]
        return unless conn_info

        session_id = conn_info[:session_id]
        conn_info[:path] ||= path
      end

      handle_message(data, path, websocket, session_id) if path
    end

    def cleanup_session(websocket)
      Drzyr.state.synchronized do
        if (conn_info = Drzyr.state.connections.delete(websocket))
          session_id = conn_info[:session_id]
          Drzyr.state.state.delete(session_id)
          Drzyr::Logger.info "Session closed and state cleared for: #{session_id}"
        end
        Drzyr.state.pending_button_presses.delete(websocket)
      end
    end

    # --- Message & Page Rendering ---

    def handle_message(data, path, websocket, session_id)
      Logger.info "Handling message: #{data.inspect}"

      case data['type']
      when 'update'
        handle_update_message(session_id, path, data)
      when 'button_press'
        handle_button_press_message(websocket, data)
      end

      result = Drzyr.rerun_page(path, websocket, session_id)
      websocket&.send({ type: 'render', **result }.to_json)
    end

    def render_page(page_config)
      builder = UIBuilder.new({}, {})
      builder.instance_exec(&page_config[:block])

      template_data = {
        server_rendered: build_server_rendered_data(builder),
        templates: load_templates_into_array,
        is_reactive: page_config[:type] == :react
      }

      template_path = File.expand_path('../public/index.mustache', __dir__)
      Mustache.render(File.read(template_path), template_data)
    end

    # --- Helper Methods ---

    def handle_update_message(session_id, path, data)
      session_entry = Drzyr.state.state[session_id]
      session_entry[:lock].synchronize do
        session_entry[:data][path][data['widget_id']] = data['value']
      end
    end

    def handle_button_press_message(websocket, data)
      Drzyr.state.synchronized do
        Drzyr.state.pending_button_presses[websocket] ||= {}
        Drzyr.state.pending_button_presses[websocket][data['widget_id']] = true
      end
    end

    def build_server_rendered_data(builder)
      {
        main_content: HtmlRenderer.render(builder.ui_elements),
        sidebar_content: HtmlRenderer.render(builder.sidebar_elements),
        navbar_content: HtmlRenderer.render(builder.navbar_elements)
      }
    end

    def load_templates
      templates = {}
      template_dir = File.expand_path('templates', __dir__)
      return {} unless Dir.exist?(template_dir)

      Dir.glob(File.join(template_dir, '*.mustache')).each do |file_path|
        name = File.basename(file_path, '.mustache')
        templates[name] = File.read(file_path)
      end
      templates
    end

    def load_templates_into_array
      load_templates.map { |name, content| { name: name, content: content } }
    end
  end

  # --- Private Module-Level Helpers ---

  class << self
    private

    def find_page_block(path)
      state.pages.dig(path, :block).tap do |block|
        Logger.info("No page block found for path: '#{path}'") unless block
      end
    end

    def execute_page_build(page_block, path, websocket, session_id)
      Logger.info "Rerunning page: '#{path}'"
      build_ui_for_page(page_block, session_id, path, websocket)
    rescue StandardError => e
      Logger.error "Error rendering page '#{path}': #{e.message}\n#{e.backtrace.join("\n")}"
      { error: { type: 'error_display', message: e.message, backtrace: e.backtrace.join("\n") } }
    end

    def build_elements(page_block, page_state, pending_presses)
      builder = UIBuilder.new(page_state, pending_presses)
      builder.instance_exec(&page_block)
      {
        elements: builder.ui_elements,
        sidebar_elements: builder.sidebar_elements,
        navbar: builder.navbar_elements
      }
    end
  end
end
