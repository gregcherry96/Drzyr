# frozen_string_literal: true

# lib/drzyr/builders/column_builder.rb
module Drzyr
  class ColumnBuilder
    attr_reader :columns

    def initialize(ui_builder)
      @ui_builder = ui_builder
      @columns = []
    end

    def column(&block)
      # Create a new, temporary builder to safely capture the content for this column.
      capture_builder = Drzyr::UIBuilder.new(@ui_builder.page_state, {})
      capture_builder.instance_exec(&block)
      @columns << capture_builder.ui_elements
    end
  end
end
