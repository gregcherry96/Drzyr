# frozen_string_literal: true

# app.rb
require_relative 'lib/drzyr'
require 'date'

# --- Helper to generate a clean ID from a title for anchor links ---
def slugify(title)
  title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
end

# --- Helper to reduce repetition for each component showcase ---
def show_case(title, description, code_string, &block)
  h2 title, id: slugify(title)
  p description
  divider
  columns do |c|
    c.column(&block) # Live component on the left
    c.column { code(code_string, language: 'ruby') } # Code on the right
  end
end

react '/' do
end

# --- Main Application ---
react '/showcase' do
  navbar do
    brand 'Drzyr Showcase'
    link 'Showcase', href: '/showcase'
  end

  sidebar do
    h3 'Drzyr Framework'
    p 'An interactive web UI framework for Ruby.'
    divider
    theme_toggle(id: 'theme_switch')
    divider

    h4 'On This Page'
    link 'Text & Display', href: '#text--display'
    link 'Input Widgets', href: '#input-widgets'
    link 'Layout & Organization', href: '#layout--organization'
    link 'Data Display', href: '#data-display'
  end

  # --- Main Content ---
  h1 'Component Showcase'
  p 'Live, interactive components are on the left. The code to generate them is on the right.'

  # --- Text & Display Section ---
  show_case('Text & Display', 'For displaying basic text content and media.',
            "h1 'Heading 1'\np 'This is a paragraph.'") do
    h1 'Heading 1'
    p 'This is a paragraph.'
  end

  show_case('Alerts', 'For displaying non-blocking notifications.',
            "alert('Success!', style: :success)") do
    alert('This is a success message.', style: :success)
  end

  show_case('LaTeX Equations', 'Render mathematical notations using MathJax.',
            "p 'Inline: $E = mc^2$'\nlatex '...formula...'") do
    p 'Inline: $E = mc^2$'
    latex 'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}'
  end

  show_case('Images', 'Displays an image from a URL or local path.',
            "image('path/to/image.png', caption: 'Logo')") do
    image('https://www.ruby-lang.org/images/header-ruby-logo@2x.png', caption: 'The official Ruby language logo.')
  end

  show_case('Code Blocks', 'Displays pre-formatted text.',
            "code(\"puts 'Hello'\", language: 'ruby')") do
    code("puts 'Hello, from a code block!'", language: 'ruby')
  end

  # --- Input Widgets Section ---
  h2 'Input Widgets', id: 'input-widgets'
  p 'For capturing user input. All widgets are interactive and stateful.'

  show_case('Button', 'Triggers an action when clicked.',
            'if button(...) ... end') do
    if button(id: 'showcase_button', text: 'Click Me')
      @page_state['showcase_clicks'] = @page_state.fetch('showcase_clicks', 0) + 1
    end
    p "Clicked #{@page_state.fetch('showcase_clicks', 0)} times."
  end

  show_case('Text Input', 'For single-line text input.',
            "name = text_input(...)\np \"Hello, \#{name}!\"") do
    name = text_input(id: 'showcase_text', label: 'Name:', default: 'World')
    p "Hello, #{name}!"
  end

  show_case('Slider', 'For selecting a number from a range.',
            "val = slider(...)\np \"Value: \#{val.to_i}\"") do
    val = slider(id: 'showcase_slider', label: 'Value:', min: 0, max: 100, default: 50)
    p "Current value: #{val.to_i}"
  end

  show_case('Checkbox', 'A boolean switch.',
            "enabled = checkbox(...)\np \"Enabled: \#{enabled}\"") do
    enabled = checkbox(id: 'showcase_checkbox', label: 'Enable Feature')
    p "Feature enabled: #{enabled}"
  end

  show_case('Radio Group', 'For selecting a single option from a list.',
            "option = radio_group(...)\np \"Selected: \#{option}\"") do
    option = radio_group(id: 'showcase_radio', label: 'Options:', options: %w[A B C])
    p "Selected: #{option}"
  end

  show_case('Select Box', 'A dropdown for single-item selection.',
            "item = selectbox(...)\np \"Chosen: \#{item}\"") do
    item = selectbox(id: 'showcase_select', label: 'Item:', options: %w[X Y Z])
    p "Chosen: #{item}"
  end

  show_case('Multi-Select', 'For selecting multiple items from a list.',
            "items = multi_select(...)\np \"Chosen: \#{items.join(', ')}\"") do
    items = multi_select(id: 'showcase_multiselect', label: 'Items:', options: %w[X Y Z], default: ['Y'])
    p "Chosen: #{items.join(', ')}"
  end

  show_case('Date Input', 'A date picker for selecting a date.',
            "date = date_input(...)\np \"Date: \#{date.strftime('%F')}\"") do
    date = date_input(id: 'showcase_date', label: 'Date:')
    p "Date: #{date.strftime('%Y-%m-%d')}"
  end

  show_case('Date Range Picker', 'For selecting a start and end date.',
            'start, finish = date_range_picker(...)') do
    start_date, end_date = date_range_picker(id: 'showcase_date_range', label: 'Select Date Range:')
    p "Start: #{start_date.strftime('%Y-%m-%d')}, End: #{end_date.strftime('%Y-%m-%d')}" if start_date && end_date
  end

  show_case('Text Area', 'For multi-line text input.',
            "text = textarea(...)\np \"Text: \#{text}\"") do
    text = textarea(id: 'showcase_textarea', label: 'Feedback:', rows: 3)
    p "Your feedback: #{text}"
  end

  # --- Layout & Organization Section ---
  h2 'Layout & Organization', id: 'layout--organization'
  p "For structuring your application's UI."

  show_case('Columns', 'Arrange content into side-by-side columns.',
            "columns do |c|\n  c.column { ... }\nend") do
    columns do |c|
      c.column { alert('Column 1', style: :success) }
      c.column { alert('Column 2', style: :warning) }
    end
  end

  show_case('Expander', 'A container that can be collapsed or expanded.',
            "expander(label: 'Click Me') do ... end") do
    expander(label: 'Click to reveal content') do
      p 'This content was hidden inside the expander.'
    end
  end

  show_case('Form Group', 'Visually group related input elements.',
            "form_group(label: 'Settings') do ... end") do
    form_group(label: 'Login Details') do
      text_input(id: 'fg_user', label: 'Username')
      password_input(id: 'fg_pass', label: 'Password')
    end
  end

  # --- Data Display Section ---
  h2 'Data Display', id: 'data-display'
  p 'For displaying tables and charts. Data is cached for performance.'

  show_case('Interactive Data Table', 'A sortable and searchable table.',
            'data_table(...)') do
    movie_data = cache('movie_data_showcase') do
      puts '--- PERF HIT: LOADING MOVIE DATA (runs once) ---'
      sleep 0.5
      [['The Shawshank Redemption', '1994'], ['The Godfather', '1972'], ['The Dark Knight', '2008']]
    end
    data_table(id: 'movie_table_showcase', columns: %w[Film Year], data: movie_data)
  end

  show_case('Chart', 'Interactive charts powered by Chart.js.',
            'chart(...)') do
    chart_type = radio_group(id: 'chart_type_docs', label: 'Chart Type:', options: %w[bar line pie],
                             default: 'bar')
    chart(
      id: 'docs_chart',
      data: {
        labels: %w[Jan Feb Mar],
        datasets: [{ label: 'Sales', data: [65, 59, 80] }]
      },
      options: { type: chart_type }
    )
  end
end
