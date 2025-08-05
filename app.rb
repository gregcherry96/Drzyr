
# frozen_string_literal: true
# app.rb

require_relative 'lib/drzyr'

def show_case(title, description, code_string, &block)
  h2 title, id: title
  p description
  divider
  columns do |c|
    c.column(&block)
    c.column { code(code_string, language: 'ruby') }
  end
end

react '/' do
  navbar do
    brand 'Drzyr Showcase'
    link 'Showcase', href: '/showcase'
    link 'Streamlit Example', href: '/streamlit-example'
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
      page_state['showcase_clicks'] = page_state.fetch('showcase_clicks', 0) + 1
    end
    p "Clicked #{page_state.fetch('showcase_clicks', 0)} times."
  end
end

get '/test' do
  h1 'Test Page'
  p 'This is a test page to demonstrate the Drzyr framework.'
  p 'You can add more content here as needed.'
end

react '/test/1' do
  navbar do
    brand 'Drzyr Showcase'
    link 'Showcase', href: '/showcase'
    link 'Test Page 1', href: '/test/1'
  end

  h1 'Test Page 1'
  p 'This is the first test page to demonstrate the Drzyr framework.'
  p 'Feel free to modify this page as needed.'
end

get '/test/2' do
  h1 'Test Page 2'
  p 'This is another test page to demonstrate the Drzyr framework.'
  p 'Feel free to modify this page as needed.'
end

# --- Streamlit Example Route ---
react '/streamlit-example' do
  navbar do
    brand 'Drzyr Showcase'
    link 'Showcase', href: '/showcase'
    link 'Streamlit Example', href: '/streamlit-example'
  end

  h1 'Streamlit Example 📊'
  p 'This page demonstrates a simple interactive chart and data table.'

  all_users = %w[Alice Bob Charly]

  form_group(label: 'Controls') do
    @selected_users = multi_select(id: 'users_multiselect', label: 'Users', options: all_users, default: all_users)
    @rolling_average_enabled = checkbox(id: 'rolling_average_toggle', label: 'Enable 7-day Rolling Average')
  end

  user_indices = @selected_users.map { |u| all_users.index(u) }.compact
  data_key = "data_#{@selected_users.join('_')}"

  all_data = cache(data_key) do
    srand(42) # for reproducibility
    Array.new(20) { Array.new(all_users.length) { randn } }
  end

  data = all_data.map { |row| user_indices.map { |i| row[i] } }

  data = rolling_average(data, 7) if @rolling_average_enabled

  tabs do |t|
    t.tab('Chart') do
      if data.empty?
        alert('Not enough data for rolling average.', style: :warning)
      else
        chart(
          id: 'line_chart_example',
          data: {
            labels: (1..data.length).to_a,
            datasets: @selected_users.map.with_index do |user, i|
              {
                label: user,
                data: data.map { |row| row[i] },
                fill: false,
                borderColor: "##{Digest::MD5.hexdigest(user)[0, 6]}",
                tension: 0.1
              }
            end
          },
          options: { type: 'line', responsive: true }
        )
      end
    end
    t.tab('Dataframe') do
      if data.empty?
        alert('Not enough data for rolling average.', style: :warning)
      else
        data_table(
          id: 'dataframe_example',
          columns: @selected_users,
          data: data.map { |row| row.map { |val| val.round(4) } }
        )
      end
    end
  end
end
