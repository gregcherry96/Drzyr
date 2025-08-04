# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'drzyr'
  spec.version       = '0.1.0'
  spec.authors       = ['Greg Cherry']
  spec.email         = ['greg.cherry96@gmail.com']

  spec.summary       = 'An interactive web UI framework for Ruby.'
  spec.description   = 'Drzyr is a lightweight framework for creating interactive web UIs with Ruby. It uses a reactive, component-based approach to building user interfaces.'
  spec.homepage      = 'https://github.com/gregcherry96/drzyr'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*', 'app.rb', 'Gemfile', 'Rakefile', 'README.md']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency "falcon", "~> 0.52.0"
  spec.add_dependency 'rack', '~> 3.1'
  spec.add_dependency 'roda', '~> 3.45'
  spec.add_dependency "roda-websockets", "~> 0.1.0"
  spec.add_dependency "async-websocket", "~> 0.30.0"
  spec.add_dependency 'tilt', '~> 2.6'

  spec.add_development_dependency 'rubocop', '~> 1.79'
end
