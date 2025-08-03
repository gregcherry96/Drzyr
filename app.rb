# app.rb
require_relative 'lib/drzyr'

Drzyr.run do
  # ===================================================================
  # == DOCUMENTATION & SHOWCASE APP
  # ===================================================================

  Drzyr.page '/' do
    # --- Universal Layout Elements ---
    navbar "Drzyr Component Showcase", links: { "Documentation" => "/" }

    sidebar do
      h3 "Drzyr Framework"
      p "An interactive web UI framework for Ruby."

      divider

      theme_toggle(id: 'theme_switch')

      divider

      h5 "About This Page"
      p "This entire page is built with Drzyr, serving as a live demonstration of its own components."

      image(
        'https://www.ruby-lang.org/images/header-ruby-logo@2x.png',
        caption: 'Powered by Ruby'
      )
    end

    # --- Main Content ---
    h1 "Component Documentation"
    p "Below is a list of all available components in the Drzyr framework. Each section includes a description, a code snippet, and a live example."

    tabs do |t|
      # --- Text & Display Tab ---
      t.tab "Text & Display" do
        h3 "Headings & Paragraphs"
        p "Used for displaying basic text content. All heading levels from h1 to h6 are supported."
        code(
          "h1 'This is a main heading'\n" +
          "h4 'This is a subheading'\n" +
          "p 'This is a standard paragraph of text.'"
        )
        h1 "This is a main heading"
        h4 "This is a subheading"
        p "This is a standard paragraph of text."

        divider

        h3 "Code Blocks"
        p "Displays pre-formatted text, ideal for showing code snippets. Supports optional language highlighting."
        code("code(\"puts 'Hello, World!'\", language: 'Ruby')")
        code("puts 'Hello, World!'", language: 'Ruby')

        divider

        h3 "LaTeX Equations"
        p "Render mathematical notations using LaTeX syntax, powered by MathJax. Inline math uses single `$` and block-level math uses the `latex` component."
        code(
          "p 'The formula for mass-energy equivalence is $E=mc^2$.'\n" +
          "latex 'x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}'"
        )
        p "The formula for mass-energy equivalence is $E=mc^2$."
        latex 'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}'

        divider

        h3 "Images"
        p "Displays an image from a URL or local path, with an optional caption."
        code("image('https://.../logo.png', caption: 'An example image')")
        p "See the sidebar for a live example."
      end

      # --- Input Widgets Tab ---
      t.tab "Input Widgets" do
        form_group(label: "Live Examples") do
          h4 "Text Input"
          code("text_input(id: 'ti_example', label: 'Your Name:', default: 'Jane Doe')")
          name = text_input(id: 'ti_example', label: 'Your Name:', default: 'Jane Doe')
          p "Current value: #{name}"

          divider

          h4 "Number Input"
          code("number_input(id: 'ni_example', label: 'Age:', default: 30)")
          age = number_input(id: 'ni_example', label: 'Age:', default: 30)
          p "Current value: #{age}"

          divider

          h4 "Text Area"
          code("textarea(id: 'ta_example', label: 'Your Bio:', rows: 4)")
          bio = textarea(id: 'ta_example', label: 'Your Bio:', rows: 4)
          p "Current value: #{bio}"

          divider

          h4 "Slider"
          code("slider(id: 'sl_example', label: 'Confidence:', min: 0, max: 100)")
          confidence = slider(id: 'sl_example', label: 'Confidence:', min: 0, max: 100)
          p "Current value: #{confidence.to_i}"

          divider

          h4 "Checkbox"
          code("checkbox(id: 'cb_example', label: 'I agree to the terms')")
          agreed = checkbox(id: 'cb_example', label: 'I agree to the terms')
          p "Current value: #{agreed}"

          divider

          h4 "Select Box"
          code("selectbox(id: 'sb_example', label: 'Favorite Color:', options: ['Red', 'Green', 'Blue'])")
          color = selectbox(id: 'sb_example', label: 'Favorite Color:', options: ['Red', 'Green', 'Blue'])
          p "Current value: #{color}"

          divider

          h4 "Multi-Select Box"
          code("multi_select(id: 'ms_example', label: 'Toppings:', options: ['Cheese', 'Pepperoni', 'Mushrooms'])")
          toppings = multi_select(id: 'ms_example', label: 'Toppings:', options: ['Cheese', 'Pepperoni', 'Mushrooms'])
          p "Current value: #{toppings.join(', ')}"

          divider

          h4 "Radio Group"
          code("radio_group(id: 'rg_example', label: 'Shipping:', options: ['Standard', 'Express'])")
          shipping = radio_group(id: 'rg_example', label: 'Shipping:', options: ['Standard', 'Express'])
          p "Current value: #{shipping}"
        end
      end

      # --- Layout & Media Tab ---
      t.tab "Layout & Media" do
        h3 "Columns"
        p "Arrange content into side-by-side columns."
        code("columns do |c|\n  c.column { ... }\n  c.column { ... }\nend")
        columns do |c|
          c.column { p 'This is the first column.' }
          c.column { p 'This is the second column.' }
        end

        divider

        h3 "Expander"
        p "A container that can be collapsed or expanded to hide content."
        code("expander(label: 'Click to see more') do ... end")
        expander(label: 'Click to see more') do
          p 'This content was hidden.'
          alert("You found the hidden content!", style: :success)
        end

        divider

        h3 "Form Group"
        p "Visually group related input elements with a title."
        code("form_group(label: 'User Details') do ... end")
        form_group(label: 'User Details') do
          text_input(id: 'fg_name', label: 'Name')
        end
      end

      # --- Feedback & Status Tab ---
      t.tab "Feedback & Status" do
        h3 "Button"
        p "A standard button to trigger actions. The `if button(...)` block runs when it's clicked."
        code(
          "if button(id: 'btn_example', text: 'Click Me')\n" +
          "  # Use @page_state to store persistent values\n" +
          "  @page_state['clicks'] = (@page_state['clicks'] || 0) + 1\n" +
          "end\n" +
          "p \"Button clicked #{@page_state.fetch('clicks', 0)} times.\""
        )

        # ** THE FIX IS HERE **
        # Check for the button press.
        if button(id: 'btn_example', text: 'Click Me')
          # Store the click count in the persistent @page_state hash.
          @page_state['clicks'] = (@page_state.fetch('clicks', 0)) + 1
        end

        # Display the count from the persistent state.
        p "Button clicked #{@page_state.fetch('clicks', 0)} times."

        divider

        h3 "Alert / Toast"
        p "Display a non-blocking notification. Supports `:success`, `:warning`, and `:error`."
        code("alert('Profile updated!', style: :success)")
        alert('Profile updated!', style: :success)

        divider

        h3 "Spinner"
        p "A loading indicator to show that the application is busy."
        code("spinner(label: 'Processing...')")
        spinner(label: 'Processing...')
      end

      # --- Charts Tab ---
      t.tab "Charts" do
        h3 "Interactive Charts"
        p "Render interactive charts using Chart.js. The data for this chart is also cached."
        code("chart(id: 'my_chart', data: ..., options: ...)")

        chart_type_docs = radio_group(id: 'chart_type_docs', label: 'Chart Type:', options: ['bar', 'line', 'pie'], default: 'bar')

        chart_data = cache("sales_data_cache") do
          puts "--- PERF HIT: Generating chart data (will run only once) ---"
          sleep 1
          {
            labels: ['January', 'February', 'March', 'April'],
            datasets: [{ label: 'Monthly Sales', data: [65, 59, 80, 81] }]
          }
        end

        chart(
          id: 'docs_chart',
          data: chart_data,
          options: { type: chart_type_docs, responsive: true }
        )
      end
    end
  end
end
