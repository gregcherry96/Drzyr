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

get '/' do
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

get '/navbar' do
  navbar do
    brand 'Drzyr Showcase'
    link 'Showcase', href: '/showcase'
    link 'Streamlit Example', href: '/streamlit-example'
  end
end

get '/sidebar' do
  sidebar do
    h3 'Drzyr Framework'
  end
end

get '/app' do
  h1 'App'
  p 'This is another test page to demonstrate the Drzyr framework.'
  p 'Feel free to modify this page as needed.'
end
