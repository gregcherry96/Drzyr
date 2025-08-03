# frozen_string_literal: true

# lib/drzyr.rb
require 'sinatra/base'
require 'faye/websocket'
require 'json'
require 'erb'
require 'securerandom'
require 'date'

# --- Top-Level DSL Methods (Sinatra-style) ---
def get(path, &block)
  Drzyr.register_page(path, :get, &block)
end

def post(path, &block)
  Drzyr.register_page(path, :post, &block)
end

def react(path, &block)
  Drzyr.register_page(path, :react, &block)
end

# A lightweight framework for creating interactive web UIs with Ruby.
module Drzyr
  class StateManager
    attr_reader :connections, :pages, :state, :pending_button_presses, :lock

    def initialize
      @connections = {}
      @pages = {}
      @state = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = {} } }
      @pending_button_presses = Hash.new { |h, k| h[k] = {} }
      @lock = Mutex.new
    end

    def synchronized(&block)
      @lock.synchronize(&block)
    end
  end

  class HtmlRenderer
    def self.render(elements)
      elements.map { |el| render_element(el) }.join("\n")
    end

    def self.render_element(el)
      sanitized_text = el[:text].to_s.gsub('<', '&lt;').gsub('>', '&gt;')

      case el[:type]
      when /heading(\d)/
        level = el[:type][7]
        "<h#{level} id='#{el[:id]}'>#{sanitized_text}</h#{level}>"
      when 'paragraph'
        "<p>#{sanitized_text}</p>"
      when 'divider'
        '<div class="divider"></div>'
      when 'code'
        "<pre class='code' data-lang='#{el[:language]}'><code>#{sanitized_text}</code></pre>"
      when 'alert'
        "<div class='toast toast-#{el[:style]}'>#{sanitized_text}</div>"
      when 'image'
        caption_html = el[:caption] ? "<figcaption class='figure-caption text-center'>#{el[:caption]}</figcaption>" : ''
        "<figure class='figure'><img class='img-responsive' src='#{el[:src]}'>#{caption_html}</figure>"
      when 'link'
        "<a href='#{el[:href]}'>#{sanitized_text}</a>"
      else
        ''
      end
    end
  end

  class NavbarBuilder
    attr_reader :elements

    def initialize(page_state)
      @page_state = page_state
      @elements = []
    end

    def brand(text)
      @elements << { type: 'navbar_brand', text: text }
    end

    def link(text, href)
      @elements << { type: 'navbar_link', text: text, href: href }
    end
  end

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

  class UIBuilder
    attr_reader :ui_elements, :sidebar_elements, :navbar_config

    def initialize(page_state, pending_presses)
      @page_state = page_state
      @pending_presses = pending_presses
      @ui_elements = []
      @sidebar_elements = []
      @capturing_sidebar = false
      @navbar_config = nil
    end

    def navbar(&block)
      navbar_builder = NavbarBuilder.new(@page_state)
      navbar_builder.instance_exec(&block)
      @navbar_config = navbar_builder.elements
    end

    def sidebar
      original_capturing_sidebar = @capturing_sidebar
      @capturing_sidebar = true
      yield
    ensure
      @capturing_sidebar = original_capturing_sidebar
    end

    (1..6).each do |level|
      define_method("h#{level}") do |text, **options|
        add_element("heading#{level}", text: text, id: options[:id])
      end
    end
    def link(text, href:)
      add_element('link', text: text, href: href)
    end

    def p(text)
      add_element('paragraph', text: text)
    end

    def table(data, headers: [])
      add_element('table', data: data, headers: headers)
    end

    def data_table(id:, data:, columns:)
      add_element('data_table', id: id, data: data, columns: columns)
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

    def cache(key)
      cache_key = "cache_#{key}"
      return @page_state[cache_key] if @page_state.key?(cache_key)

      result = yield
      @page_state[cache_key] = result
    end

    def theme_toggle(id:, label: 'Dark Mode', default_dark: false)
      is_dark = checkbox(id: id, label: label)
      theme = is_dark ? 'dark' : 'light'
      @page_state['theme'] = theme
      add_element('theme_setter', theme: theme)
      theme
    end

    def chart(id:, data:, options: {})
      default_options = { animation: { duration: 0 }, responsive: true }
      final_options = deep_merge(default_options, options)
      add_element('chart', id: id, data: data, options: final_options)
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

    def date_range_picker(id:, label:, default: nil, error: nil)
      default_range = default || [Date.today, Date.today + 7]
      default_str = "#{default_range[0]} - #{default_range[1]}"

      value_str = @page_state.fetch(id, default_str)

      add_input_element('date_range_picker', id, label, value_str, error: error)

      value_str.split(' - ').map do |d|
        Date.parse(d)
      rescue StandardError
        nil
      end.compact
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
      add_element('tabs', id: tabs_id, labels: tab_builder.tab_labels, active_tab: active_tab,
                          content: tab_builder.tabs_content[active_tab])
    end

    def columns
      builder = ColumnBuilder.new(self)
      yield builder
      add_element('columns_container', columns: builder.columns)
    end

    def capture_elements(&block)
      original_ui_elements = @ui_elements
      @ui_elements = []
      original_sidebar_elements = @sidebar_elements
      @sidebar_elements = []
      instance_exec(&block)
      captured = @capturing_sidebar ? @sidebar_elements : @ui_elements
      @ui_elements = original_ui_elements
      @sidebar_elements = original_sidebar_elements
      captured
    end

    private

    def deep_merge(h1, h2)
      h1.merge(h2) do |_key, old_val, new_val|
        old_val.is_a?(Hash) && new_val.is_a?(Hash) ? deep_merge(old_val, new_val) : new_val
      end
    end

    def add_element(type, attributes)
      target_array = @capturing_sidebar ? @sidebar_elements : @ui_elements
      target_array << attributes.merge(type: type)
    end

    def add_input_element(type, id, label, value, error: nil, **attrs)
      add_element(type, { id: id, label: label, value: value, error: error, **attrs })
      value
    end
  end

  class Logger
    def self.info(message)
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] \e[32mINFO\e[0m  #{message}"
    end
  end

  class RequestLogger
    def initialize(app)
      @app = app
    end

    def call(env)
      start_time = Time.now
      status, headers, body = @app.call(env)
      end_time = Time.now

      unless env['PATH_INFO'].start_with?('/main.css', '/javascript.js', '/websocket')
        Logger.info "#{env['REQUEST_METHOD']} #{env['PATH_INFO']} - \e[36m#{status}\e[0m in #{((end_time - start_time) * 1000).round(2)}ms"
      end

      [status, headers, body]
    end
  end

  module_function

  def state
    @state ||= StateManager.new
  end

  def register_page(path, type, &block)
    state.pages[path] = { type: type, block: block }
  end

  def run!
    Logger.info 'Starting Drzyr server...'

    state.pages.each do |path, config|
      handler = proc do
        builder = UIBuilder.new({}, {}) # Initial render is always stateless
        builder.instance_exec(&config[:block])
        server_rendered_data = {
          main_content: HtmlRenderer.render(builder.ui_elements),
          sidebar_content: HtmlRenderer.render(builder.sidebar_elements),
          navbar: builder.navbar_config
        }
        erb :index, locals: { server_rendered: server_rendered_data }
      end

      case config[:type]
      when :react, :get
        Server.get(path, &handler)
      when :post
        Server.post(path, &config[:block])
      end
    end

    Server.set :port, 4567
    Server.set :bind, '0.0.0.0'
    Server.run!
  end

  def rerun_page(path, ws, session_id)
    page_block = state.pages.dig(path, :block)
    return {} unless page_block

    elements = nil
    sidebar_elements = nil
    navbar_config = nil
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

  class Server < Sinatra::Base
    disable :logging
    use RequestLogger

    set :public_folder, File.expand_path('public', __dir__)
    set :views, File.expand_path('public', __dir__)

    get '/websocket' do
      halt(400) unless Faye::WebSocket.websocket?(request.env)
      ws = Faye::WebSocket.new(request.env)

      ws.on(:open) do
        Drzyr.state.synchronized do
          session_id = SecureRandom.hex(16)
          Drzyr.state.connections[ws] = { session_id: session_id, path: nil }
          Drzyr::Logger.info "New connection opened with session ID: #{session_id}"
        end
      end

      ws.on(:message) do |event|
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

      ws.on(:close) do
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
      ws.rack_response
    end

    private

    def handle_message(data, path, ws, session_id)
      app_state = Drzyr.state
      app_state.synchronized do
        case data['type']
        when 'client_ready'
          # No state change needed, just trigger a re-render for the new client
        when 'update'
          app_state.state[session_id][path][data['widget_id']] = data['value']
        when 'button_press'
          app_state.pending_button_presses[ws] ||= {}
          app_state.pending_button_presses[ws][data['widget_id']] = true
        end
      end
      # Rerun the page logic and send the full UI state back to the client
      result = Drzyr.rerun_page(path, ws, session_id)
      ws&.send({ type: 'render', **result }.to_json)
    end
  end
end

at_exit { Drzyr.run! unless ENV['DRZYR_NO_RUN'] }
