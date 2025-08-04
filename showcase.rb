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

# --- Helper for rolling average ---
def rolling_average(data, window_size)
  return data if window_size <= 1

  averaged_data = []
  data.each_with_index do |_row, i|
    next if i < window_size - 1

    window = data[(i - window_size + 1)..i]
    # Transpose the window to get columns, then average each column
    new_row = window.transpose.map { |col| col.sum / window_size.to_f }
    averaged_data << new_row
  end
  averaged_data
end

# --- Helper to generate normally distributed random numbers (approximates numpy.random.randn) ---
def randn
  theta = 2 * Math::PI * rand
  rho = Math.sqrt(-2 * Math.log(1 - rand))
  rho * Math.cos(theta)
end

react '/' do
end

# --- Main Application ---
react '/showcase' do
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

react '/streamlit-example' do
  navbar do
    brand 'Drzyr Showcase'
    link 'Showcase', href: '/showcase'
    link 'Streamlit Example', href: '/streamlit-example'
  end

  h1 'Streamlit Example 📊'
  p 'This page demonstrates a simple interactive chart and data table, similar to what you can create with Streamlit.'

  all_users = %w[Alice Bob Charly]

  form_group(label: 'Controls') do
    @selected_users = multi_select(id: 'users_multiselect', label: 'Users', options: all_users, default: all_users)
    @rolling_average = checkbox(id: 'rolling_average_toggle', label: 'Enable 7-day Rolling Average')
  end

  # Generate data based on selected users
  user_indices = @selected_users.map { |u| all_users.index(u) }.compact

  data_key = "data_#{@selected_users.join('_')}"

  all_data = cache(data_key) do
    srand(42) # for reproducibility
    Array.new(20) { Array.new(all_users.length) { randn } }
  end

  # Select columns for the chosen users
  data = all_data.map do |row|
    user_indices.map { |i| row[i] }
  end

  data = rolling_average(data, 7) if @rolling_average

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
                borderColor: "##{Digest::MD5.hexdigest(user)[0, 6]}", # Generate a color from the user name
                tension: 0.1
              }
            end
          },
          options: {
            type: 'line',
            responsive: true,
            maintainAspectRatio: false,
            scales: {
              y: {
                beginAtZero: true
              }
            }
          }
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
          data: data.map { |row| row.map { |val| val.round(4) } } # Round for display
        )
      end
    end
  end
end

# routes/examples.rb

# This file is now loaded into the Drzyr::Server context.
# All routes are defined directly on the server class.

# --- A simple in-memory "database" for our examples ---
$users = {
  1 => { name: 'Alice', role: 'admin' },
  2 => { name: 'Bob', role: 'user' }
}
$next_user_id = 3

# --- Filters ---
before '/api/*' do
  puts "--> API Request to #{request.path} at #{Time.now.iso8601}"
end

before '/secret' do
  unless request.env['HTTP_X_API_KEY'] == 'supersecret'
    halt 401, { 'Content-Type' => 'application/json' }, { error: 'Unauthorized' }.to_json
  end
end

after '/api/*' do
  puts "<-- API Request to #{request.path} Finished"
end

# --- Standard Routes ---
get '/hello' do
  'Hello, World!' # This will be returned as an API response
end

get '/secret' do
  'This is the secret area.'
end

# --- UI Route ---
# Any route can build a UI by simply using the UI DSL methods.
get '/welcome' do
  h1 "Welcome to Drzyr on Sinatra!"
  p "Any route can now build a UI with the simple DSL."
  p "The current path is: #{request.path}"
end

# --- Namespaced API Routes ---
namespace '/api/v1' do
  get '/users' do
    $users
  end

  post '/users' do
    new_user = JSON.parse(request.body.read)
    $users[$next_user_id] = new_user
    $next_user_id += 1
    status 201
    body new_user.to_json
  end

  put '/users/:id' do
    user_id = params['id'].to_i
    if $users[user_id]
      $users[user_id] = JSON.parse(request.body.read)
      $users[user_id]
    else
      halt 404, { error: 'User not found' }.to_json
    end
  end

  # ... (other API routes like patch and delete follow the same Sinatra pattern)
end


# --- Interactive React Route ---
# `react` is now just a GET route that builds a UI.
get '/counter' do
  # `page_state` is now available through the UI DSL helper
  clicks = page_state.fetch('clicks', 0)

  if button(id: 'increment_button', text: 'Increment')
    page_state['clicks'] = clicks + 1
  end

  h1 'Simple Counter'
  p "Button has been clicked #{page_state.fetch('clicks', 0)} times."
end
