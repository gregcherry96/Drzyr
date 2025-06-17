# app.rb
require_relative 'lib/ruby_flow'

RubyFlow.run do
  RubyFlow.page '/' do

    # --- Section 1: Headings and Paragraphs ---
    # Demonstrates: h1, p, h6
    h1 "RubyFlow Conf 2025 Registration"
    p "Welcome to the registration page for the first-ever conference dedicated to RubyFlow! Please fill out the form below to secure your spot."
    h6 "Location: Aberdeen, Scotland, United Kingdom"

    # --- Section 2: Attendee Details ---
    # Demonstrates: h2, text_input, password_input, date_input
    h2 "Your Details"

    full_name = text_input(id: 'full_name', label: 'Full Name:')
    password = password_input(id: 'password', label: 'Create a password for your ticket:')
    dob_str = date_input(id: 'dob', label: 'Date of Birth:')

    # --- Section 3: Ticket Selection ---
    # Demonstrates: h3, selectbox, number_input, h4 (for reactive output)
    h3 "Ticket Options"

    ticket_prices = { 'Standard Access' => 100, 'VIP Pass' => 250, 'Student' => 50 }
    ticket_type = selectbox(
      id: 'ticket_type',
      label: 'Choose your ticket type:',
      options: ticket_prices.keys
    )

    quantity_str = number_input(id: 'quantity', label: 'Number of Tickets:', default: 1)
    quantity = quantity_str.to_i

    # Reactive calculation
    total_cost = ticket_prices[ticket_type] * quantity
    h4 "Subtotal: £#{total_cost}"

    # --- Section 4: Add-ons & Preferences ---
    # Demonstrates: h3, checkbox
    h3 "Preferences"
    wants_workshop = checkbox(id: 'workshop', label: 'Sign up for the pre-conference workshop (£25 extra)')

    # --- Section 5: Summary & Submission ---
    # Demonstrates: h2, h5, button
    h2 "Registration Summary"

    p "Please review your details before completing your registration."
    h5 "Name: #{full_name.empty? ? 'Not provided' : full_name}"
    h5 "Ticket Type: #{quantity}x #{ticket_type}"
    h5 "Workshop: #{wants_workshop ? 'Yes' : 'No'}"

    # Final price calculation
    final_cost = wants_workshop ? total_cost + 25 : total_cost
    h4 "Final Total: £#{final_cost}"

    if button(id: 'submit_reg', text: 'Complete Registration')
      h3 "Thank you for registering, #{full_name}!"
      p "A confirmation has been sent to your (imaginary) email address."
    end

    movie_data = [
      ['The Shawshank Redemption', 'Crime, Drama', '14 October 1994'],
      ['The Godfather', 'Crime, Drama', '24 March 1972'],
      ['The Dark Knight', 'Action, Crime, Drama', '18 July 2008'],
      ['Pulp Fiction', 'Crime, Drama', '14 October 1994'],
      ['Forrest Gump', 'Drama, Romance', '6 July 1994']
    ]

    h1 "Filmography"
    p "Displaying data using the new table component. This component is ideal for showing structured, tabular data."

    # Define the headers for our table
    headers = ['Name', 'Genre', 'Release Date']

    # Create the table
    table(movie_data, headers: headers)

    h3 "Reactive Table Example"
    p "You can also build tables dynamically."

    num_rows_str = number_input(id: 'num_rows', label: 'Number of Rows to Show:', default: movie_data.length)
    num_rows = num_rows_str.to_i

    # Only take the number of rows selected by the user
    dynamic_data = movie_data.first(num_rows)

    table(dynamic_data, headers: headers)



    h1 "Simple Loan Calculator"
    p "Use the sliders to adjust the loan amount and term to see your estimated monthly payment update in real-time."

    # --- Sliders for Input ---

    # Slider for the loan amount. We'll format the output later.
    amount = slider(
      id: 'loan_amount',
      label: 'Loan Amount',
      min: 1000,
      max: 50000,
      step: 1000,
      default: 15000
    )

    # Slider for the loan term in years.
    term_years = slider(
      id: 'loan_term',
      label: 'Loan Term (Years)',
      min: 1,
      max: 30,
      default: 5
    )

    # --- Calculation ---

    # We'll use a fixed annual interest rate for this demo.
    annual_interest_rate = 0.065 # 6.5%

    # Avoid division by zero if term is 0, though our slider min is 1.
    if term_years > 0
      term_months = term_years * 12
      monthly_interest_rate = annual_interest_rate / 12

      # Standard formula for an amortizing loan.
      numerator = monthly_interest_rate * ((1 + monthly_interest_rate)**term_months)
      denominator = ((1 + monthly_interest_rate)**term_months) - 1
      monthly_payment = amount * (numerator / denominator)
    else
      monthly_payment = 0
    end

    # --- Output ---

    p "Assuming a fixed annual interest rate of #{(annual_interest_rate * 100).round(1)}%."

    # Use h2 for the most important output.
    h2 "Estimated Monthly Payment: £#{monthly_payment.round(2)}"

    p "Over a term of #{term_years.to_i} years, your total repayment would be £#{(monthly_payment * term_months).round(2)}."
  end

  RubyFlow.page "/c" do
    h1 "Reactive Dashboard"
    p "Change the values in the inputs to see the UI update in real time."

    # 1. Define variables in the outer scope so they are shared by all columns.
    num1 = 0
    num2 = 0
    name = ''
    sensitivity = 0

    columns do |c|
      # --- Column 1: Inputs ---
      c.column do
        h3 "Inputs"

        # 2. Assign the results to the variables defined in the outer scope.
        num1 = number_input(id: 'num1', label: 'First Number', default: 10).to_i
        num2 = number_input(id: 'num2', label: 'Second Number', default: 5).to_i
        name = text_input(id: 'ti1', label: 'Your Name', default: 'friend')
        sensitivity = slider(id: 's1', label: 'Sensitivity', min: 0, max: 100, default: 50)
      end

      # --- Column 2: Reactive Outputs ---
      c.column do
        h3 "Live Outputs"

        # 3. These variables are now accessible here because they were defined
        #    in the higher scope.
        h4 "Real-time Sum"
        p "#{num1} + #{num2} = #{num1 + num2}"

        h4 "Slider Value"
        p "Current sensitivity is: #{sensitivity.to_i}"

        if sensitivity > 75
          p "Warning: High sensitivity detected!"
        end
      end

      # --- Column 3: Actions ---
      c.column do
          h3 "Actions"

          if button(id: 'b1', text: 'Submit')
              h4 "✅ Submission Received!"
              p "Thanks for submitting, #{name}."
          else
              p "Press the button to trigger an action."
          end
      end
    end
  end
end
