# frozen_string_literal: true

require 'mustache'

module Drzyr
  @state_lock = Mutex.new

  def self.state
    @state_lock.synchronize do
      @state ||= StateManager.new
    end
  end

  def self.register_page(path, type, &block)
    state.pages[path] = { type: type, block: block }
  end

  def self.rerun_page(path, ws, session_id)
    page_block = state.pages.dig(path, :block)
    unless page_block
      Logger.info "No page block found for path: '#{path}'"
      return {}
    end

    Logger.info "Rerunning page: '#{path}'"
    build_ui_for_page(page_block, session_id, path, ws)
  end

  def self.build_ui_for_page(page_block, session_id, path, ws)
    elements, sidebar_elements, navbar_elements = nil
    state.synchronized do
      page_state = state.state[session_id][path]
      pending_presses = state.pending_button_presses.fetch(ws, {})
      builder = UIBuilder.new(page_state, pending_presses)
      builder.instance_exec(&page_block)
      elements = builder.ui_elements
      sidebar_elements = builder.sidebar_elements
      navbar_elements = builder.navbar_elements
    end
    { elements: elements, sidebar_elements: sidebar_elements, navbar: navbar_elements }
  end

  class Server < Roda
    plugin :public, root: File.expand_path('../public', __dir__)

    route do |r|
      r.public

      r.on 'websocket' do
        handle_websocket(r)
      end

      page_config = Drzyr.state.pages[r.path]
      if page_config
        render_page(page_config)
      else
        # This is the new fallback for unknown routes
        response.status = 404
        "<h1>404 Not Found</h1><p>The page you requested could not be found.</p>"
      end
    end

    private

    def handle_websocket(r)
      halt(400) unless Faye::WebSocket.websocket?(r.env)
      ws = Faye::WebSocket.new(r.env)

      ws.on(:open) { setup_new_session(ws) }
      ws.on(:message) { |event| process_message(ws, event) }
      ws.on(:close) { cleanup_session(ws) }

      r.halt(ws.rack_response)
    end

    def setup_new_session(ws)
      Drzyr.state.synchronized do
        session_id = SecureRandom.hex(16)
        Drzyr.state.connections[ws] = { session_id: session_id, path: nil }
        Drzyr::Logger.info "New connection opened with session ID: #{session_id}"
      end
    end

    def process_message(ws, event)
      data = JSON.parse(event.data)
      path = data['path']
      conn_info = Drzyr.state.connections[ws]

      unless conn_info
        ws.close
        return
      end

      session_id = conn_info[:session_id]
      Drzyr.state.synchronized { conn_info[:path] ||= path }

      handle_message(data, path, ws, session_id) if path
    end

    def cleanup_session(ws)
      Drzyr.state.synchronized do
        if (conn_info = Drzyr.state.connections.delete(ws))
          session_id = conn_info[:session_id]
          Drzyr.state.state.delete(session_id)
          Drzyr::Logger.info "Session closed and state cleared for: #{session_id}"
        end
        Drzyr.state.pending_button_presses.delete(ws)
      end
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

    def render_page(page_config)
      # For the initial render, the page state is empty
      builder = UIBuilder.new({}, {})
      builder.instance_exec(&page_config[:block])

      server_rendered_data = {
        main_content: HtmlRenderer.render(builder.ui_elements),
        sidebar_content: HtmlRenderer.render(builder.sidebar_elements),
        navbar_content: HtmlRenderer.render(builder.navbar_elements)
      }

      templates_array = load_templates.map do |name, content|
        { name: name, content: content }
      end

      mustache_template_path = File.expand_path('../public/index.mustache', __dir__)
      mustache_template = File.read(mustache_template_path)

      Mustache.render(mustache_template, {
        server_rendered: server_rendered_data,
        templates: templates_array,
        # Add the new flag here. Only 'react' pages are interactive.
        is_reactive: page_config[:type] == :react
      })
    end

    def handle_message(data, path, ws, session_id)
      Logger.info "Handling message: #{data.inspect}"
      app_state = Drzyr.state
      app_state.synchronized do
        case data['type']
        when 'update'
          app_state.state[session_id][path][data['widget_id']] = data['value']
        when 'button_press'
          app_state.pending_button_presses[ws] ||= {}
          app_state.pending_button_presses[ws][data['widget_id']] = true
        end
      end
      result = Drzyr.rerun_page(path, ws, session_id)
      ws&.send({ type: 'render', **result }.to_json)
    end
  end
end
