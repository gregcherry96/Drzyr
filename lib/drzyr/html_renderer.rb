# frozen_string_literal: true

# lib/drzyr/html_renderer.rb
module Drzyr
  # Renders UI element hashes into static HTML strings.
  # This is used for the initial server-side render of a page before the
  # interactive WebSocket connection takes over.
  class HtmlRenderer
    # A list of components that can be rendered directly from their type name.
    SIMPLE_COMPONENTS = %w[
      navbar_brand navbar_link paragraph divider code alert image link button
      checkbox data_table date_input date_range_picker number_input password_input
      slider spinner table textarea text_input theme_setter latex
    ].freeze

    def self.render(elements)
      return '' if elements.nil?

      elements.map { |element| render_element(element) }.join("\n")
    end

    def self.render_element(element)
      element_data = element.dup
      element_data[:text] = element_data[:text].to_s.gsub('<', '&lt;').gsub('>', '&gt;') if element_data[:text]
      dispatch_render(element_data)
    end

    # --- Private Helper Methods ---

    class << self
      private

      def dispatch_render(data)
        type = data[:type]
        if SIMPLE_COMPONENTS.include?(type)
          render_simple_component(data)
        elsif type.start_with?('heading')
          render_heading_component(data)
        else
          render_complex_component(data)
        end
      end

      def render_complex_component(data)
        case data[:type]
        when 'columns_container'
          render_columns_component(data)
        when 'expander', 'form_group'
          render_block_component(data)
        when 'radio_group', 'selectbox'
          render_options_component(data)
        when 'tabs'
          render_tabs_component(data)
        else
          Drzyr::Logger.warn "Unknown component type in HtmlRenderer: #{data[:type]}"
          ''
        end
      end

      def render_simple_component(data)
        Templating.render(data[:type], data)
      end

      def render_heading_component(data)
        data[:level] = data[:type][7]
        Templating.render('heading', data)
      end

      def render_columns_component(data)
        data[:columns] = data[:columns].map do |col_elements|
          { content: render(col_elements) }
        end
        Templating.render('columns_container', data)
      end

      def render_block_component(data)
        data[:content] = render(data[:content])
        Templating.render(data[:type], data)
      end

      def render_options_component(data)
        data[:options] = data[:options].map do |opt|
          { value: opt, selected: opt == data[:value] }
        end
        Templating.render(data[:type], data)
      end

      def render_tabs_component(data)
        data[:labels] = data[:labels].map do |label|
          { value: label, active: label == data[:active_tab] }
        end
        data[:content] = render(data[:content])
        Templating.render('tabs', data)
      end
    end
  end
end
