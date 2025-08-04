# frozen_string_literal: true

# lib/drzyr/html_renderer.rb
module Drzyr
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
end
