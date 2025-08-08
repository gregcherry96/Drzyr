# Drzyr

[![Gem Version](https://badge.fury.io/rb/drzyr.svg)](https://badge.fury.io/rb/drzyr)
[![MIT License](https://img.shields.io/badge/license-MIT-green)](https://opensource.org/licenses/MIT)

**Drzyr is an interactive web UI framework for Ruby, think Python's Streamlit but for Rubyists.**

Drzyr allows you to build web applications with a reactive, component-based approach, similar to modern JavaScript frameworks, but with the power and simplicity of Ruby. It's designed to be easy to use and extend, making it a great choice for both new and experienced Ruby developers.

## 🚀 Features

Drzyr provides a wide range of components and features to help you build modern, interactive web applications:

* **Text & Display**: Headings, paragraphs, alerts, LaTeX equations, images, and code blocks.
* **Input Widgets**: Buttons, text inputs, sliders, checkboxes, select boxes, and more.
* **Layout & Organization**: Columns, expanders, and tabs to structure your application's UI.
* **Data Display**: Interactive data tables and charts to visualize your data.

## 🛠️ Getting Started

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'drzyr'
```

And then execute:
```bash
bundle install
```

or install it yourself as:
```bash
gem install drzyr
```

## Usage
Create a config.ru file in your project's root directory:

```ruby
require './app'

run Drzyr::Server.freeze.app
```

Then create an app.rb file with the following content:

```ruby
require 'drzyr'

# Drzyr uses a reactive, stateful approach.
# The `react` block re-renders automatically on user interaction.
react '/' do
  # Add a navigation bar with a brand and links
  navbar do
    brand 'My App'
    link 'Home', href: '/'
  end

  # Create a sidebar for navigation or controls
  sidebar do
    h3 'Controls'
    theme_toggle(id: 'theme_switch')
  end

  # Use headings and paragraphs for text content
  h1 'Hello, Drzyr!'
  p 'This is an interactive Drzyr application.'

  # Create stateful input widgets
  # The `button` method returns true when clicked
  if button(id: 'my_button', text: 'Click Me')
    # Use page_state to store and access state
    page_state['clicks'] = (page_state['clicks'] || 0) + 1
  end

  # Display the current state
  p "You've clicked the button #{page_state.fetch('clicks', 0)} times."

  # Display an alert message
  alert('This is a success message.', style: :success)

  # Showcase other components
  h2 'More Components'
  divider

  # Create a two-column layout
  columns do |c|
    c.column do
      h3 'Inputs'
      text_input(id: 'my_text', label: 'Enter some text')
      slider(id: 'my_slider', label: 'A slider', min: 0, max: 100)
    end
    c.column do
      h3 'Display'
      code("puts 'Hello, World!'", language: 'ruby')
      latex('E = mc^2')
    end
  end
end
```

Then run your application with:

```bash
rackup
```
