# frozen_string_literal: true

# lib/drzyr/builders/tab_builder.rb

module Drzyr
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
end
