# frozen_string_literal: true

# lib/drzyr/html_renderer.rb
module Drzyr
  class HtmlRenderer
    def self.render(elements)
      return '' if elements.nil?
      elements.map { |el| render_element(el) }.join("\n")
    end

    def self.render_element(el)
      element_data = el.dup
      if element_data[:text]
        element_data[:text] = element_data[:text].to_s.gsub('<', '&lt;').gsub('>', '&gt;')
      end

      case element_data[:type]
      # Add the new 'latex' type to this list of simple components
      when 'navbar_brand', 'navbar_link', 'paragraph', 'divider', 'code', 'alert', 'image', 'link', 'button', 'checkbox', 'data_table', 'date_input', 'date_range_picker', 'number_input', 'password_input', 'slider', 'spinner', 'table', 'textarea', 'text_input', 'theme_setter', 'latex'
        Templating.render(element_data[:type], element_data)
      when /heading(\d)/
        element_data[:level] = element_data[:type][7]
        Templating.render('heading', element_data)
      when 'columns_container'
        element_data[:columns] = element_data[:columns].map do |col_elements|
          { content: render(col_elements) }
        end
        Templating.render('columns_container', element_data)
      when 'expander', 'form_group'
        element_data[:content] = render(element_data[:content])
        Templating.render(element_data[:type], element_data)
      when 'radio_group', 'selectbox'
        element_data[:options] = element_data[:options].map do |opt|
          { value: opt, selected: opt == element_data[:value] }
        end
        Templating.render(element_data[:type], element_data)
      when 'tabs'
        element_data[:labels] = element_data[:labels].map do |label|
          { value: label, active: label == element_data[:active_tab] }
        end
        element_data[:content] = render(element_data[:content])
        Templating.render('tabs', element_data)
      else
        Drzyr::Logger.warn "Unknown component type encountered in HtmlRenderer: #{element_data[:type]}"
        ''
      end
    end
  end
end
