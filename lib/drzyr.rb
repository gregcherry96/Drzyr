# lib/drzyr.rb
# frozen_string_literal: true

# --- External Gems ---
require 'sinatra/base'
require 'faye/websocket'
require 'json'
require 'erb'
require 'securerandom'
require 'date'

# --- Drzyr Components ---
require_relative 'drzyr/version'
require_relative 'drzyr/logger'
require_relative 'drzyr/state_manager'
require_relative 'drzyr/html_renderer'
require_relative 'drzyr/builders/column_builder'
require_relative 'drzyr/builders/navbar_builder'
require_relative 'drzyr/builders/tab_builder'
require_relative 'drzyr/builders/ui_builder' # Contains the UI_DSL module

module Drzyr
  # This is the core application class. All routes and logic will be attached to it.
  class App < Sinatra::Base
    # --- Sinatra Configuration ---
    set :server, 'puma'
    set :sockets, []
    set :root, -> { File.expand_path('../..', __dir__) }
    set :views, -> { File.join(root, 'lib/public') }
    set :public_folder, -> { File.join(root, 'lib/public') }


    # --- Drzyr State Management ---
    def self.state
      @state ||= Drzyr::StateManager.new
    end

    def state
      self.class.state
    end

    # --- UI DSL ---
    helpers UI_DSL

    # --- Re-rendering Logic ---
    def rerun_page(path, ws, session_id)
      page_block = self.class.routes['GET'].find { |route| route[0].match(path) }&.last
      return {}.to_json unless page_block

      page_state = state.state[session_id][path]
      pending_presses = state.pending_button_presses.fetch(ws, {})

      initialize_ui_state(page_state, nil, pending_presses)
      instance_exec(&page_block)

      {
        type: 'render',
        elements: @ui_elements,
        sidebar_elements: @sidebar_elements,
        navbar: @navbar_config
      }
    end

    # --- Sinatra Hooks ---
    before do
      initialize_ui_state({}, request, {})
    end

    # CORRECTED: The condition is now robust. If any UI content was generated,
    # this block will now correctly replace the response body with the rendered HTML.
    after do
      ui_content = render_ui_if_needed
      if ui_content
        body ui_content
      end
    end

    # --- View Helpers ---
    helpers do
      def render_ui_if_needed
        if @ui_elements&.any? || @sidebar_elements&.any?
          server_rendered_data = {
            main_content: Drzyr::HtmlRenderer.render(@ui_elements),
            sidebar_content: Drzyr::HtmlRenderer.render(@sidebar_elements),
            navbar: @navbar_config
          }
          erb :index, locals: { server_rendered: server_rendered_data }, layout: false
        end
      end
    end

    # --- WebSocket Handling ---
    get '/websocket' do
      if Faye::WebSocket.websocket?(request.env)
        app_instance = self
        ws = Faye::WebSocket.new(request.env)

        ws.on :open do |event|
          session_id = SecureRandom.hex(16)
          settings.sockets << ws
          state.connections[ws] = { session_id: session_id, path: nil }
          Drzyr::Logger.info "New connection opened with session ID: #{session_id}"
        end

        ws.on :message do |event|
          data = JSON.parse(event.data)
          path = data['path']
          session_id = state.connections[ws][:session_id]

          case data['type']
          when 'update'
            state.state[session_id][path][data['widget_id']] = data['value']
          when 'button_press'
            state.pending_button_presses[ws] ||= {}
            state.pending_button_presses[ws][data['widget_id']] = true
          end

          result = app_instance.rerun_page(path, ws, session_id)
          ws.send(result.to_json)
        end

        ws.on :close do |event|
          settings.sockets.delete(ws)
          conn_info = state.connections.delete(ws)
          if conn_info
            session_id = conn_info[:session_id]
            state.state.delete(session_id)
            Drzyr::Logger.info "Session closed and state cleared for: #{session_id}"
          end
          ws = nil
        end

        ws.rack_response
      else
        status 400
        'Expected a WebSocket connection.'
      end
    end
  end
end
