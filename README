# ✨ Drzyr ✨

[![Gem Version](https://badge.fury.io/rb/drzyr.svg)](https://badge.fury.io/rb/drzyr)
[![MIT License](https://img.shields.io/badge/license-MIT-green)](https://opensource.org/licenses/MIT)

An interactive web UI framework for Ruby.

Drzyr allows you to build web applications with a reactive, component-based approach, similar to modern JavaScript frameworks, but with the power and simplicity of Ruby. It's designed to be easy to use and extend, making it a great choice for both new and experienced Ruby developers.

## 🚀 Features

Drzyr provides a wide range of components and features to help you build modern, interactive web applications:

* **Text & Display**: Headings, paragraphs, alerts, LaTeX equations, images, and code blocks.
* **Input Widgets**: Buttons, text inputs, sliders, checkboxes, radio groups, select boxes, and more.
* **Layout & Organization**: Columns, expanders, and form groups to structure your application's UI.
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

run Sinatra::Application
```

Then create an app.rb file with the following content:

```ruby
require 'drzyr'

react '/' do
  h1 'Hello, Drzyr!'
  p 'This is a simple Drzyr application.'

  if button(id: 'my_button', text: 'Click Me')
    p 'You clicked the button!'
  end
end
```

Then run your application with:

```bash
rackup config.ru
```
