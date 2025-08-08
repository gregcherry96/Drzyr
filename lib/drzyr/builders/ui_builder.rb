# frozen_string_literal: true

# lib/drzyr/builders/ui_builder.rb
module Drzyr
  # The primary DSL for building user interfaces.
  # An instance of this class is passed to the user's page block, providing
  # methods to create various UI components like text, inputs, layouts, and charts.
  class UIBuilder
    # Extends UIBuilder with methods for display components.
    module DisplayComponents
      def link(text, href:)
        add_element('link', text: text, href: href)
      end

      def p(text)
        add_element('paragraph', text: text)
      end

      (1..6).each do |level|
        define_method("h#{level}") do |text, **options|
          add_element("heading#{level}", text: text, id: options[:id])
        end
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
    end

    # Extends UIBuilder with methods for input components.
    module InputComponents
      def button(id:, text:)
        add_element('button', id: id, text: text)
        @pending_presses.delete(id)
      end

      def slider(id:, label:, min:, max:, **options)
        default = options.fetch(:default, min)
        value = @page_state.fetch(id, default).to_f
        attrs = { min: min, max: max, step: options.fetch(:step, 1) }
        add_input_element(type: 'slider', id: id, label: label, value: value.to_s, error: options[:error], **attrs)
        value
      end

      def text_input(id:, label:, default: '', error: nil)
        value = @page_state.fetch(id, default)
        add_input_element(type: 'text_input', id: id, label: label, value: value, error: error)
      end

      def number_input(id:, label:, default: 0, error: nil)
        value = @page_state.fetch(id, default)
        numeric_value = value.to_s.include?('.') ? value.to_f : value.to_i
        add_input_element(type: 'number_input', id: id, label: label, value: value.to_s, error: error)
        numeric_value
      end

      def password_input(id:, label:, default: '', error: nil)
        value = @page_state.fetch(id, default)
        add_input_element(type: 'password_input', id: id, label: label, value: value, error: error)
      end

      def date_input(id:, label:, default: nil, error: nil)
        default_str = default || Date.today.to_s
        value_str = @page_state.fetch(id, default_str)
        add_input_element(type: 'date_input', id: id, label: label, value: value_str, error: error)
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
        add_input_element(type: 'date_range_picker', id: id, label: label, value: value_str, error: error)
        value_str.split(' - ').map do |d|
          Date.parse(d)
        rescue StandardError
          nil
        end.compact
      end

      def checkbox(id:, label:, error: nil)
        value = @page_state.fetch(id, false)
        add_input_element(type: 'checkbox', id: id, label: label, value: value, error: error)
      end

      def selectbox(id:, label:, options:, error: nil)
        value = @page_state.fetch(id, options.first)
        add_input_element(type: 'selectbox', id: id, label: label, value: value, error: error, options: options)
      end

      def textarea(id:, label:, default: '', rows: 3, error: nil)
        value = @page_state.fetch(id, default)
        add_input_element(type: 'textarea', id: id, label: label, value: value, error: error, rows: rows)
        value
      end

      def multi_select(id:, label:, options:, default: [], error: nil)
        value = @page_state.fetch(id, default)
        selection = value.is_a?(Array) ? value : value.to_s.split(',')
        add_input_element(type: 'multi_select', id: id, label: label, value: selection, error: error, options: options)
        selection
      end

      def radio_group(id:, label:, options:, default: nil, error: nil)
        default_value = default || options.first
        value = @page_state.fetch(id, default_value)
        add_input_element(type: 'radio_group', id: id, label: label, value: value, error: error, options: options)
        value
      end
    end

    # Extends UIBuilder with methods for layout components.
    module LayoutComponents
      def navbar(&block)
        Drzyr::Logger.debug 'Entering navbar block'
        navbar_builder = NavbarBuilder.new(@page_state)
        navbar_builder.instance_exec(&block)
        @navbar_elements = navbar_builder.elements
        Drzyr::Logger.debug 'Exiting navbar block'
      end

      def sidebar
        original_capturing = @capturing_sidebar
        @capturing_sidebar = true
        yield
      ensure
        @capturing_sidebar = original_capturing
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

      def tabs
        tab_builder = TabBuilder.new(self)
        yield tab_builder
        active_tab = find_or_set_active_tab(tab_builder)
        add_element('tabs',
                    id: "tabs_#{tab_builder.tab_labels.join.hash.abs}",
                    labels: tab_builder.tab_labels,
                    active_tab: active_tab,
                    content: tab_builder.tabs_content[active_tab])
      end

      def columns
        builder = ColumnBuilder.new(self)
        yield builder
        add_element('columns_container', columns: builder.columns)
      end
    end

    include DisplayComponents
    include InputComponents
    include LayoutComponents

    attr_reader :ui_elements, :sidebar_elements, :navbar_elements, :page_state, :pending_presses

    def initialize(page_state, pending_presses)
      @page_state = page_state
      @pending_presses = pending_presses
      @ui_elements = []
      @sidebar_elements = []
      @capturing_sidebar = false
      @navbar_elements = nil
    end

    def table(data, headers: [])
      add_element('table', data: data, headers: headers)
    end

    def data_table(id:, data:, columns:)
      add_element('data_table', id: id, data: data, columns: columns)
    end

    def cache(_key)
      @page_state[cache_key] ||= yield
    end

    def theme_toggle(id:, label: 'Dark Mode')
      is_dark = checkbox(id: id, label: label)
      theme = is_dark ? 'dark' : 'light'
      @page_state['theme'] = theme
      add_element('theme_setter', theme: theme)
      theme
    end

    def chart(id:, options: {})
      default_opts = { animation: { duration: 0 }, responsive: true }
      final_opts = deep_merge(default_opts, options)
      add_element('chart', id: id, data: final_opts, options: final_opts)
    end

    private

    def _capture_content(&block)
      capture_builder = Drzyr::UIBuilder.new(@page_state, @pending_presses)
      capture_builder.instance_exec(&block)
      capture_builder.ui_elements
    end

    def deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_key, old_val, new_val|
        old_val.is_a?(Hash) && new_val.is_a?(Hash) ? deep_merge(old_val, new_val) : new_val
      end
    end

    def find_or_set_active_tab(tab_builder)
      tabs_id = "tabs_#{tab_builder.tab_labels.join.hash.abs}"
      active_tab = @page_state.fetch(tabs_id, tab_builder.tab_labels.first)

      tab_builder.tab_labels.each do |label|
        tab_button_id = "#{tabs_id}_#{label}"
        if @pending_presses.delete(tab_button_id)
          active_tab = label
          @page_state[tabs_id] = active_tab
        end
      end
      active_tab
    end

    def add_element(type, attributes)
      target_array = @capturing_sidebar ? @sidebar_elements : @ui_elements
      target_array << attributes.merge(type: type)
      Drzyr::Logger.debug "Adding element '#{type}' to #{@capturing_sidebar ? 'sidebar' : 'main UI'}"
    end

    def add_input_element(attributes)
      add_element(attributes[:type], attributes)
    end
  end
end
