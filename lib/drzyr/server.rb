# lib/drzyr/server.rb

# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/namespace'
require 'async/websocket'
require 'json'
require 'securerandom'

module Drzyr
  class Server < Sinatra::Base
    # --- Sinatra Configuration ---
    register Sinatra::Namespace
    set :public_folder, -> { File.expand_path('../public', __dir__) }
    set :views, -> { File.expand_path('../public', __dir__) }

    # --- Helpers ---
    helpers do
      include UI_DSL

      def render_ui_if_needed
        if @ui_elements.any? || @sidebar_elements.any?
          server_rendered_data = {
            main_content: HtmlRenderer.render(@ui_elements),
            sidebar_content: HtmlRenderer.render(@sidebar_elements),
            navbar: @navbar_config
          }
          erb :index, locals: { server_rendered: server_rendered_data }, layout: false
        end
      end
    end

    # --- Middleware Hooks ---
    before do
      initialize_ui_state({}, request)
    end

    after do
      ui_content = render_ui_if_needed
      if ui_content && !response.body.first&.is_a?(String)
         body ui_content
      end
    end

    # --- WebSocket Handling with async-websocket ---
    get '/websocket' do
      # Hijack the connection from the webserver to handle it with async-websocket
      hijack do |socket|
        connection = Async::WebSocket::Connection.new(socket)
        session_id = nil
        path = nil

        Drzyr.state.synchronized do
          session_id = SecureRandom.hex(16)
          Drzyr.state.connections[connection] = { session_id: session_id, path: nil }
          Drzyr::Logger.info "New connection opened with session ID: #{session_id}"
        end

        while (message = connection.read)
          data = JSON.parse(message)
          path ||= data['path']
          conn_info = Drzyr.state.connections[connection]
          break unless conn_info

          Drzyr.state.synchronized { conn_info[:path] ||= path }
          handle_message(data, path, connection, session_id) if path
        end
      rescue Protocol::WebSocket::ClosedError
        Drzyr::Logger.info "WebSocket connection closed cleanly."
      ensure
        Drzyr.state.synchronized do
          if (conn_info = Drzyr.state.connections.delete(connection))
            session_id = conn_info[:session_id]
            Drzyr.state.state.delete(session_id)
            Drzyr::Logger.info "Session closed and state cleared for: #{session_id}"
          end
          Drzyr.state.pending_button_presses.delete(connection)
        end
        connection.close
      end
    end

    # --- Private Methods ---
    private

    def handle_message(data, path, ws, session_id)
      app_state = Drzyr.state
      app_state.synchronized do
        case data['type']
        when 'client_ready'
        when 'update'
          app_state.state[session_id][path][data['widget_id']] = data['value']
        when 'button_press'
          app_state.pending_button_presses[ws] ||= {}
          app_state.pending_button_presses[ws][data['widget_id']] = true
        end
      end
      result = Drzyr.rerun_page(path, ws, session_id)
      ws.write({ type: 'render', **result }.to_json)
      ws.flush
    end
  end
end
