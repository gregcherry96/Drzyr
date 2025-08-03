# app.rb
require_relative 'lib/drzyr'
require 'date'

# --- Helper to generate a clean ID from a title for anchor links ---
def slugify(title)
  title.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
end

# --- Define the structure of the documentation page ---
SECTIONS = {
  "Text & Display" => {
    description: "For displaying basic text content and media.",
    components: [
      { title: "Headings & Paragraphs", code: "h1 'Title'\np 'Paragraph...'",
        block: -> {
          h1 "Heading 1"
          p "This is a paragraph."
        }},
      { title: "Alerts", code: "alert('Success!', style: :success)",
        block: -> {
          alert("This is a success message.", style: :success)
        }},
      { title: "LaTeX Equations", code: "latex 'E=mc^2'",
        block: -> {
          p "Inline: $E=mc^2$"
          latex 'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}'
        }},
      { title: "Images", code: "image('path/to/image.png', caption: 'Logo')",
        block: -> {
          image(
            'https://www.ruby-lang.org/images/header-ruby-logo@2x.png',
            caption: 'The official Ruby language logo.'
          )
        }},
      { title: "Code Blocks", code: "code(\"puts 'Hello'\", language: 'ruby')",
        block: -> {
          code("puts 'Hello, from a code block!'", language: 'ruby')
        }}
    ]
  },
  "Input Widgets" => {
    description: "For capturing user input. All widgets are interactive and stateful.",
    components: [
      { title: "Button", code: "if button(...) ... end",
        block: -> {
          if button(id: 'showcase_button', text: 'Click Me')
            @page_state['showcase_clicks'] = (@page_state.fetch('showcase_clicks', 0)) + 1
          end
          p "Clicked #{@page_state.fetch('showcase_clicks', 0)} times."
        }},
      { title: "Text Input", code: "name = text_input(...)\np \"Hello, \#{name}!\"",
        block: -> {
          name = text_input(id: 'showcase_text', label: 'Name:', default: 'World')
          p "Hello, #{name}!"
        }},
      { title: "Slider", code: "val = slider(...)\np \"Value: \#{val.to_i}\"",
        block: -> {
          val = slider(id: 'showcase_slider', label: 'Value:', min: 0, max: 100, default: 50)
          p "Current value: #{val.to_i}"
        }},
      { title: "Checkbox", code: "enabled = checkbox(...)\np \"Enabled: \#{enabled}\"",
        block: -> {
          enabled = checkbox(id: 'showcase_checkbox', label: 'Enable Feature')
          p "Feature enabled: #{enabled}"
        }},
      { title: "Radio Group", code: "option = radio_group(...)\np \"Selected: \#{option}\"",
        block: -> {
          option = radio_group(id: 'showcase_radio', label: 'Options:', options: ['A', 'B', 'C'])
          p "Selected: #{option}"
        }},
      { title: "Select Box", code: "item = selectbox(...)\np \"Chosen: \#{item}\"",
        block: -> {
          item = selectbox(id: 'showcase_select', label: 'Item:', options: ['X', 'Y', 'Z'])
          p "Chosen: #{item}"
        }},
      { title: "Multi-Select", code: "items = multi_select(...)\np \"Chosen: \#{items.join(', ')}\"",
        block: -> {
          items = multi_select(id: 'showcase_multiselect', label: 'Items:', options: ['X', 'Y', 'Z'], default: ['Y'])
          p "Chosen: #{items.join(', ')}"
        }},
      { title: "Date Input", code: "date = date_input(...)\np \"Date: \#{date.strftime('%F')}\"",
        block: -> {
          date = date_input(id: 'showcase_date', label: 'Date:')
          p "Date: #{date.strftime('%Y-%m-%d')}"
        }},
      { title: "Text Area", code: "text = textarea(...)\np \"Text: \#{text}\"",
        block: -> {
            text = textarea(id: 'showcase_textarea', label: 'Feedback:', rows: 3)
            p "Your feedback: #{text}"
        }}
    ]
  },
  "Layout & Organization" => {
    description: "For structuring your application's UI.",
    components: [
        { title: "Columns", code: "columns do |c|\n  c.column { ... }\nend",
            block: -> {
                columns do |c|
                    c.column { alert("Column 1", style: :success) }
                    c.column { alert("Column 2", style: :warning) }
                end
            }},
        { title: "Expander", code: "expander(label: 'Click Me') do ... end",
            block: -> {
                expander(label: 'Click to reveal content') do
                    p "This content was hidden inside the expander."
                end
            }},
        { title: "Form Group", code: "form_group(label: 'Settings') do ... end",
            block: -> {
                form_group(label: 'Login Details') do
                    text_input(id: 'fg_user', label: 'Username')
                    password_input(id: 'fg_pass', label: 'Password')
                end
            }}
    ]
  },
  "Data Display" => {
    description: "For displaying tables and charts. Data is cached for performance.",
    components: [
      { title: "Interactive Data Table", code: "data_table(...)",
        block: -> {
          movie_data = cache("movie_data_showcase") do
            puts "--- PERF HIT: LOADING MOVIE DATA (runs once) ---"
            sleep 0.5
            [['The Shawshank Redemption', '1994'], ['The Godfather', '1972'], ['The Dark Knight', '2008']]
          end
          data_table(id: 'movie_table_showcase', columns: ['Film', 'Year'], data: movie_data)
        }},
      { title: "Chart", code: "chart(...)",
        block: -> {
          chart_type = radio_group(id: 'chart_type_docs', label: 'Chart Type:', options: ['bar', 'line', 'pie'], default: 'bar')
          chart(
            id: 'docs_chart',
            data: {
              labels: ['Jan', 'Feb', 'Mar'],
              datasets: [{ label: 'Sales', data: [65, 59, 80] }]
            },
            options: { type: chart_type }
          )
        }}
    ]
  }
}

# --- A fully interactive to-do list application ---
react '/todo' do
  # --- Initialize the list of to-dos in the page's state ---
  # This will only run once when the page is first loaded.
  @page_state['todos'] ||= [
    { id: SecureRandom.hex(4), text: 'Create a Drzyr to-do app' },
    { id: SecureRandom.hex(4), text: 'Showcase its features' },
    { id: SecureRandom.hex(4), text: 'Make it awesome' }
  ]

  # --- Universal Layout ---
  navbar do
    brand "My To-Do List"
  end

  # --- Main Content ---
  h1 "Drzyr To-Do App"
  p "A simple application to manage your daily tasks."

  # --- Form for adding new to-dos ---
  form_group(label: 'Add a new item') do
    new_todo_text = text_input(id: 'new_todo_text', label: 'Task description:')

    if button(id: 'add_todo', text: 'Add Task') && !new_todo_text.empty?
      # Add the new to-do to the list
      @page_state['todos'] << { id: SecureRandom.hex(4), text: new_todo_text }
      # Clear the input field by updating its state
      @page_state['new_todo_text'] = ''
    end
  end

  divider

  # --- Display the list of to-dos ---
  h3 "Your Tasks"

  if @page_state['todos'].empty?
    alert("You've completed all your tasks! 🎉", style: :success)
  else
    # Iterate through the to-dos and create a button to remove each one
    @page_state['todos'].each do |todo|
      columns do |c|
        # Column for the to-do text
        c.column { p todo[:text] }

        # Column for the "Done" button
        c.column do
          if button(id: "done_#{todo[:id]}", text: 'Done')
            # Remove the to-do from the list by its ID
            @page_state['todos'].delete_if { |item| item[:id] == todo[:id] }
          end
        end
      end
    end
  end
end

react '/nav' do
  navbar do
    brand "Drzyr Showcase"
    link "Home", href: "/"

    if @page_state.fetch('show_extra_link', false)
      link "Extra Link", href: "#"
    end
  end

  sidebar do
    checkbox(id: 'show_extra_link', label: 'Show extra navbar link')
  end
end

react '/' do
  navbar do
    brand "Drzyr Showcase"
    link "Home", href: "/"

    if @page_state['show_extra_link']
      link "Extra Link", href: "#"
    end
  end

  sidebar do
    h3 "Drzyr Framework"
    p "An interactive web UI framework for Ruby."
    divider
    theme_toggle(id: 'theme_switch')
    divider
    checkbox(id: 'show_extra_link', label: 'Show extra navbar link')
    divider

    h4 "On This Page"
    SECTIONS.each do |title, data|
      link title, href: "##{slugify(title)}"
    end
  end

  # --- Main Content ---
  h1 "Component Showcase"
  p "Live, interactive components are on the left. The code to generate them is on the right."

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
