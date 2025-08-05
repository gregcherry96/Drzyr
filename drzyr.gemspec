# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'drzyr'
  spec.version       = '0.1.0'
  spec.authors       = ['Greg Cherry']
  spec.email         = ['greg.cherry96@gmail.com']

  spec.summary       = 'An interactive web UI framework for Ruby.'
  spec.description   = 'Drzyr is a lightweight framework for creating interactive web UIs with Ruby.
It uses a reactive, component-based approach to building user interfaces.'
  spec.homepage      = 'https://github.com/gregcherry96/drzyr'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*', 'app.rb', 'Gemfile', 'Rakefile', 'README.md']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) do |f|
    File.basename(f)
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'base64'
  spec.add_dependency 'faye-websocket'
  spec.add_dependency 'puma'
  spec.add_dependency 'rackup'
  spec.add_dependency 'sinatra'
  spec.add_dependency 'sinatra-contrib'
  spec.add_dependency 'sinatra-reloader'

  spec.add_development_dependency 'rubocop'
end
