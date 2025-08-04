# frozen_string_literal: true

# lib/drzyr/builders/navbar_builder.rb
module Drzyr
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
end
