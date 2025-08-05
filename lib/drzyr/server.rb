# frozen_string_literal: true

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
    build_ui_for_page(page_block, session_id, ws)
  end

  def self.build_ui_for_page(page_block, session_id, ws)
    elements, sidebar_elements, navbar_config = nil
    state.synchronized do
      page_state = state.state[session_id]
      pending_presses = state.pending_button_presses.fetch(ws, {})
      builder = UIBuilder.new(page_state, pending_presses)
      builder.instance_exec(&page_block)
      elements = builder.ui_elements
      sidebar_elements = builder.sidebar_elements
      navbar_config = builder.navbar_config
    end
    { elements: elements, sidebar_elements: sidebar_elements, navbar: navbar_config }
  end

  class Server < Roda
    plugin :public, root: File.expand_path('../public', __dir__)
    plugin :render, views: File.expand_path('../public', __dir__)

    route do |r|
      r.public

      r.on 'websocket' do
        handle_websocket(r)
      end

      page_config = Drzyr.state.pages[r.path]
      render_page(page_config) if page_config
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

    def render_page(page_config)
      builder = UIBuilder.new({}, {}) # Initial render is stateless
      builder.instance_exec(&page_config[:block])
      server_rendered_data = {
        main_content: HtmlRenderer.render(builder.ui_elements),
        sidebar_content: HtmlRenderer.render(builder.sidebar_elements),
        navbar: builder.navbar_config
      }
      view('index', locals: { server_rendered: server_rendered_data }, layout: false)
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
