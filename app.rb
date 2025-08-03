# frozen_string_literal: true

# app.rb
require_relative 'lib/drzyr'
require 'date'

# --- Helper to generate a clean ID from a title for anchor links ---
def slugify(title)
  title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
end

# --- Define the structure of the documentation page ---
# This makes the page easy to manage and extend.
SECTIONS = {
  'Text & Display' => {
    description: 'For displaying basic text content and media.',
    components: [
      { title: 'Headings & Paragraphs', code: "h1 'Title'\np 'Paragraph...'",
        block: lambda {
          h1 'Heading 1'
          p 'This is a paragraph.'
        } },
      { title: 'Alerts', code: "alert('Success!', style: :success)",
        block: lambda {
          alert('This is a success message.', style: :success)
        } },
      { title: 'LaTeX Equations', code: "latex 'E=mc^2'",
        block: lambda {
          p 'Inline: $E=mc^2$'
          latex 'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}'
        } },
      { title: 'Images', code: "image('path/to/image.png', caption: 'Logo')",
        block: lambda {
          image(
            'https://www.ruby-lang.org/images/header-ruby-logo@2x.png',
            caption: 'The official Ruby language logo.'
          )
        } },
      { title: 'Code Blocks', code: "code(\"puts 'Hello'\", language: 'ruby')",
        block: lambda {
          code("puts 'Hello, from a code block!'", language: 'ruby')
        } }
    ]
  },
  'Input Widgets' => {
    description: 'For capturing user input. All widgets are interactive and stateful.',
    components: [
      { title: 'Button', code: 'if button(...) ... end',
        block: lambda {
          if button(id: 'showcase_button', text: 'Click Me')
            @page_state['showcase_clicks'] = @page_state.fetch('showcase_clicks', 0) + 1
          end
          p "Clicked #{@page_state.fetch('showcase_clicks', 0)} times."
        } },
      { title: 'Text Input', code: "name = text_input(...)\np \"Hello, \#{name}!\"",
        block: lambda {
          name = text_input(id: 'showcase_text', label: 'Name:', default: 'World')
          p "Hello, #{name}!"
        } },
      { title: 'Slider', code: "val = slider(...)\np \"Value: \#{val.to_i}\"",
        block: lambda {
          val = slider(id: 'showcase_slider', label: 'Value:', min: 0, max: 100, default: 50)
          p "Current value: #{val.to_i}"
        } },
      { title: 'Checkbox', code: "enabled = checkbox(...)\np \"Enabled: \#{enabled}\"",
        block: lambda {
          enabled = checkbox(id: 'showcase_checkbox', label: 'Enable Feature')
          p "Feature enabled: #{enabled}"
        } },
      { title: 'Radio Group', code: "option = radio_group(...)\np \"Selected: \#{option}\"",
        block: lambda {
          option = radio_group(id: 'showcase_radio', label: 'Options:', options: %w[A B C])
          p "Selected: #{option}"
        } },
      { title: 'Select Box', code: "item = selectbox(...)\np \"Chosen: \#{item}\"",
        block: lambda {
          item = selectbox(id: 'showcase_select', label: 'Item:', options: %w[X Y Z])
          p "Chosen: #{item}"
        } },
      { title: 'Multi-Select', code: "items = multi_select(...)\np \"Chosen: \#{items.join(', ')}\"",
        block: lambda {
          items = multi_select(id: 'showcase_multiselect', label: 'Items:', options: %w[X Y Z], default: ['Y'])
          p "Chosen: #{items.join(', ')}"
        } },
      { title: 'Date Input', code: "date = date_input(...)\np \"Date: \#{date.strftime('%F')}\"",
        block: lambda {
          date = date_input(id: 'showcase_date', label: 'Date:')
          p "Date: #{date.strftime('%Y-%m-%d')}"
        } },
      { title: 'Date Range Picker', code: 'start, finish = date_range_picker(...)',
        block: lambda {
          start_date, end_date = date_range_picker(
            id: 'showcase_date_range',
            label: 'Select Date Range:'
          )
          if start_date && end_date
            p "Start: #{start_date.strftime('%Y-%m-%d')}, End: #{end_date.strftime('%Y-%m-%d')}"
          else
            p 'Please select a valid date range.'
          end
        } },
      { title: 'Text Area', code: "text = textarea(...)\np \"Text: \#{text}\"",
        block: lambda {
          text = textarea(id: 'showcase_textarea', label: 'Feedback:', rows: 3)
          p "Your feedback: #{text}"
        } }
    ]
  },
  'Layout & Organization' => {
    description: "For structuring your application's UI.",
    components: [
      { title: 'Columns', code: "columns do |c|\n  c.column { ... }\nend",
        block: lambda {
          columns do |c|
            c.column { alert('Column 1', style: :success) }
            c.column { alert('Column 2', style: :warning) }
          end
        } },
      { title: 'Expander', code: "expander(label: 'Click Me') do ... end",
        block: lambda {
          expander(label: 'Click to reveal content') do
            p 'This content was hidden inside the expander.'
          end
        } },
      { title: 'Form Group', code: "form_group(label: 'Settings') do ... end",
        block: lambda {
          form_group(label: 'Login Details') do
            text_input(id: 'fg_user', label: 'Username')
            password_input(id: 'fg_pass', label: 'Password')
          end
        } }
    ]
  },
  'Data Display' => {
    description: 'For displaying tables and charts. Data is cached for performance.',
    components: [
      { title: 'Interactive Data Table', code: 'data_table(...)',
        block: lambda {
          movie_data = cache('movie_data_showcase') do
            puts '--- PERF HIT: LOADING MOVIE DATA (runs once) ---'
            sleep 0.5
            [['The Shawshank Redemption', '1994'], ['The Godfather', '1972'], ['The Dark Knight', '2008']]
          end
          data_table(id: 'movie_table_showcase', columns: %w[Film Year], data: movie_data)
        } },
      { title: 'Chart', code: 'chart(...)',
        block: lambda {
          chart_type = radio_group(id: 'chart_type_docs', label: 'Chart Type:', options: %w[bar line pie], default: 'bar')
          chart(
            id: 'docs_chart',
            data: {
              labels: %w[Jan Feb Mar],
              datasets: [{ label: 'Sales', data: [65, 59, 80] }]
            },
            options: { type: chart_type }
          )
        } }
    ]
  }
}.freeze

# --- Main Application ---
react '/' do
  # --- Universal Layout ---
  navbar do |_nav|
    brand 'Drzyr Showcase'
    link 'Showcase', href: '/'
  end

  sidebar do
    h3 'Drzyr Framework'
    p 'An interactive web UI framework for Ruby.'
    divider
    theme_toggle(id: 'theme_switch')
    divider

    h4 'On This Page'
    SECTIONS.each_key do |title|
      link title, href: "##{slugify(title)}"
    end
  end

  # --- Main Content ---
  h1 'Component Showcase'
  p 'Live, interactive components are on the left. The code to generate them is on the right.'

  SECTIONS.each do |title, data|
    h2 title, id: slugify(title)
    p data[:description]

    data[:components].each do |comp|
      divider
      columns do |c|
        c.column do
          h4 comp[:title]
          instance_exec(&comp[:block])
        end
        c.column { code(comp[:code], language: 'ruby') }
      end
    end
  end
end
