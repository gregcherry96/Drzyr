# frozen_string_literal: true

# app.rb
require_relative 'lib/drzyr'

Drzyr.run do
  Drzyr.page '/' do
    # --- Application State ---
    @errors ||= {}
    @submitted_successfully ||= false
    @show_source ||= false

    # navbar 'Drzyr Showcase', links: { 'Home' => '/', 'Dashboard' => '/c' }

    sidebar do
      h3 'Drzyr Controls'
      p 'A Ruby web framework.'

      divider

      # --- Add the Theme Toggle to the sidebar ---
      theme_toggle(id: 'theme_switch')

      divider

      @show_source = !@show_source if checkbox(id: 'show_source', label: 'Show Source Code')
    end

    # --- Main Page Content ---
    h1 'Drzyr Framework Showcase'

    # Show source code if the sidebar checkbox is ticked
    if @show_source
      expander(label: 'Application Source (app.rb)', expanded: true) do
        code(File.read(__FILE__), language: 'ruby')
      end
    end

    divider

    movie_data = [
      ['The Shawshank Redemption', 'Crime, Drama', '1994'],
      ['The Godfather', 'Crime, Drama', '1972'],
      ['The Dark Knight', 'Action, Crime, Drama', '2008'],
      ['Pulp Fiction', 'Crime, Drama', '1994'],
      ['Forrest Gump', 'Drama, Romance', '1994'],
      ['The Lord of the Rings: The Return of the King', 'Action, Adventure, Drama', '2003'],
      ['Schindler\'s List', 'Biography, Drama, History', '1993']
    ]

    data_table(
      id: 'movie_table',
      columns: ['Name', 'Genre', 'Release Year'],
      data: movie_data
    )
  end
end
