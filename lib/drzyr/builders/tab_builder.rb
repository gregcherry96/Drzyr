# frozen_string_literal: true

# lib/drzyr/builders/tab_builder.rb
module Drzyr
  # A DSL builder for creating interactive tabbed content sections.
  # It is used within the `UIBuilder#tabs` method to define the labels and
  # content for each individual tab.
  class TabBuilder
    attr_reader :tabs_content, :tab_labels

    def initialize(ui_builder)
      @ui_builder = ui_builder
      @tabs_content = {}
      @tab_labels = []
    end

    def tab(label, &block)
      @tab_labels << label
      # Use the new, safe capturing pattern for each tab.
      capture_builder = Drzyr::UIBuilder.new(@ui_builder.page_state, @ui_builder.pending_presses)
      capture_builder.instance_exec(&block)
      @tabs_content[label] = capture_builder.ui_elements
    end
  end
end
