# lib/drzyr/server.rb

# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'roda'
require 'async/websocket'

module Drzyr
  module_function

  @state_lock = Mutex.new

  def state
    return @state if @state

    @state_lock.synchronize do
      @state ||= StateManager.new
    end
    @state
  end

  def register_page(path, type, &block)
    state.pages[path] = { type: type, block: block }
  end

  def rerun_page(path, ws, session_id)
    page_block = state.pages.dig(path, :block)
    Logger.info "Rerunning page: '#{path}'. Page block found: #{!page_block.nil?}"
    return {} unless page_block

    elements, sidebar_elements, navbar_config = nil

    state.synchronized do
      page_state = state.state[session_id][path]
      pending_presses_for_ws = state.pending_button_presses.fetch(ws, {})

      builder = UIBuilder.new(page_state, pending_presses_for_ws)
      builder.instance_exec(&page_block)

      elements = builder.ui_elements
      sidebar_elements = builder.sidebar_elements
      navbar_config = builder.navbar_config
    end

    { elements: elements, sidebar_elements: sidebar_elements, navbar: navbar_config }
  end

  # The Server is now a Roda application using the async-websockets plugin
  class Server < Roda
    plugin :public, root: File.expand_path('../public', __dir__)
    plugin :render, views: File.expand_path('../public', __dir__)
    plugin :websockets

    route do |r|
      r.public # Serve static files

      # WebSocket connection handling
      r.on 'websocket' do
        r.websocket do |ws|
          session_id = nil
          path = nil

          Drzyr.state.synchronized do
            session_id = SecureRandom.hex(16)
            Drzyr.state.connections[ws] = { session_id: session_id, path: nil }
            Drzyr::Logger.info "New connection opened with session ID: #{session_id}"
          end

          while (event_data = ws.read)
            data = JSON.parse(event_data)
            path ||= data['path']

            conn_info = Drzyr.state.connections[ws]
            break unless conn_info

            Drzyr.state.synchronized { conn_info[:path] ||= path }
            handle_message(data, path, ws, session_id) if path
          end
        rescue Protocol::WebSocket::ClosedError
          # This is a normal closure, log it cleanly
          Drzyr::Logger.info "WebSocket connection closed cleanly."
        rescue IOError, Errno::EPIPE => e
          # This handles other potential I/O errors
          Drzyr::Logger.info "WebSocket Error: #{e.class} - #{e.message}"
        ensure
          # Cleanup on close
          Drzyr.state.synchronized do
            conn_info = Drzyr.state.connections.delete(ws)
            if conn_info
              session_id = conn_info[:session_id]
              Drzyr.state.state.delete(session_id)
              Drzyr::Logger.info "Session closed and state cleared for: #{session_id}"
            end
            Drzyr.state.pending_button_presses.delete(ws)
          end
          ws = nil
        end
      end

      # Capture the current path to look up in our pages hash
      page_config = Drzyr.state.pages[r.path]

      if page_config
        builder = UIBuilder.new({}, {}) # Initial render is stateless
        builder.instance_exec(&page_config[:block])
        server_rendered_data = {
          main_content: HtmlRenderer.render(builder.ui_elements),
          sidebar_content: HtmlRenderer.render(builder.sidebar_elements),
          navbar: builder.navbar_config
        }
        view('index', locals: { server_rendered: server_rendered_data }, layout: false)
      end
    end

    private

    def handle_message(data, path, ws, session_id)
      Logger.info "Handling message: #{data.inspect}"
      app_state = Drzyr.state
      app_state.synchronized do
        case data['type']
        when 'client_ready'
          # No state change needed, just trigger a re-render
        when 'update'
          app_state.state[session_id][path][data['widget_id']] = data['value']
        when 'button_press'
          app_state.pending_button_presses[ws] ||= {}
          app_state.pending_button_presses[ws][data['widget_id']] = true
        end
      end
      result = Drzyr.rerun_page(path, ws, session_id)
      ws&.write({ type: 'render', **result }.to_json)
      ws&.flush
    end
  end
end
