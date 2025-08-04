# lib/drzyr/server.rb

# frozen_string_literal: true

require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra-websocket'
require 'json'
require 'securerandom'

module Drzyr
  module_function

  def self.rerun_page(path, ws, session_id)
    page_block = Drzyr::Server.routes['GET'].find { |route| route[0].match(path) }&.last
    Drzyr::Logger.info "Rerunning page: '#{path}'. Page block found: #{!page_block.nil?}"
    return {}.to_json unless page_block

    state.synchronized do
      page_state = state.state[session_id][path]
      pending_presses = state.pending_button_presses.fetch(ws, {})
      builder = UIBuilder.new(page_state, pending_presses)
      builder.instance_exec(&page_block)
      {
        type: 'render',
        elements: builder.ui_elements,
        sidebar_elements: builder.sidebar_elements,
        navbar: builder.navbar_config
      }
    end
  end

  class Server < Sinatra::Base
    register Sinatra::Namespace
    set :public_folder, -> { File.expand_path('../public', __dir__) }
    set :views, -> { File.expand_path('../public', __dir__) }
    set :server, 'puma'
    set :sockets, []

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

    before do
      initialize_ui_state({}, request)
    end

    after do
      ui_content = render_ui_if_needed
      if ui_content && body.empty?
        body ui_content
      end
    end

    get '/websocket' do
      request.websocket do |ws|
        ws.onopen do
          session_id = SecureRandom.hex(16)
          ws.instance_variable_set(:@session_id, session_id)
          settings.sockets << ws
          Drzyr.state.connections[ws] = { session_id: session_id, path: nil }
          Drzyr::Logger.info "New connection opened with session ID: #{session_id}"
        end
        ws.onmessage do |msg|
          data = JSON.parse(msg)
          path = data['path']
          session_id = ws.instance_variable_get(:@session_id)
          handle_message(data, path, ws, session_id)
        end
        ws.onclose do
          settings.sockets.delete(ws)
          conn_info = Drzyr.state.connections.delete(ws)
          if conn_info
            session_id = conn_info[:session_id]
            Drzyr.state.state.delete(session_id)
            Drzyr::Logger.info "Session closed and state cleared for: #{session_id}"
          end
        end
      end
    end

    private

    def handle_message(data, path, ws, session_id)
      app_state = Drzyr.state
      result = nil
      app_state.synchronized do
        case data['type']
        when 'update'
          app_state.state[session_id][path][data['widget_id']] = data['value']
        when 'button_press'
          app_state.pending_button_presses[ws] ||= {}
          app_state.pending_button_presses[ws][data['widget_id']] = true
        end
        result = Drzyr.rerun_page(path, ws, session_id)
      end
      ws.send(result.to_json)
    end
  end
end
