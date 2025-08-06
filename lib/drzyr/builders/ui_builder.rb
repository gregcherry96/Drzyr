# frozen_string_literal: true

# lib/drzyr/builders/ui_builder.rb
module Drzyr
  class UIBuilder
    attr_reader :ui_elements, :sidebar_elements, :navbar_elements, :page_state

    def initialize(page_state, pending_presses)
      @page_state = page_state
      @pending_presses = pending_presses
      @ui_elements = []
      @sidebar_elements = []
      @capturing_sidebar = false
      @navbar_elements = nil
    end

    def navbar(&block)
      Drzyr::Logger.debug "Entering navbar block"
      navbar_builder = NavbarBuilder.new(@page_state)
      navbar_builder.instance_exec(&block)
      @navbar_elements = navbar_builder.elements
      Drzyr::Logger.debug "Exiting navbar block. Found #{@navbar_elements.size} navbar elements."
    end

    def sidebar
      Drzyr::Logger.debug "Entering sidebar block"
      original_capturing_sidebar = @capturing_sidebar
      @capturing_sidebar = true
      yield
    ensure
      @capturing_sidebar = original_capturing_sidebar
      Drzyr::Logger.debug "Exiting sidebar block. Found #{@sidebar_elements.size} sidebar elements."
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
      content = is_expanded ? _capture_content(&block) : []
      add_element('expander', id: expander_id, label: label, expanded: is_expanded, content: content)
    end

    def form_group(label:, &block)
      content = _capture_content(&block)
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

    private

    # New private helper method for capturing content safely.
    def _capture_content(&block)
        capture_builder = Drzyr::UIBuilder.new(@page_state, {})
        capture_builder.instance_exec(&block)
        capture_builder.ui_elements
    end

    def deep_merge(h1, h2)
      h1.merge(h2) do |_key, old_val, new_val|
        old_val.is_a?(Hash) && new_val.is_a?(Hash) ? deep_merge(old_val, new_val) : new_val
      end
    end

    def add_element(type, attributes)
      target_array = @capturing_sidebar ? @sidebar_elements : @ui_elements
      target_array << attributes.merge(type: type)
      # Log which element is being added and where
      target_name = @capturing_sidebar ? "sidebar_elements" : "ui_elements"
      Drzyr::Logger.debug "Adding element of type '#{type}' to #{target_name}"
    end

    def add_input_element(type, id, label, value, error: nil, **attrs)
      add_element(type, { id: id, label: label, value: value, error: error, **attrs })
      value
    end
  end
end
