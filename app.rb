# frozen_string_literal: true

# app.rb
require_relative 'lib/drzyr'

Drzyr.run do
  Drzyr.page '/' do
    # --- State for validation and submission ---
    @errors ||= {}
    @submitted_successfully ||= false

    # Define variables in the outer scope to be accessible everywhere
    full_name = ''
    password = ''

    h1 'RubyFlow Conf 2025 Registration'
    # ... (intro text) ...
    divider

    # ** THE FIX IS HERE **
    # --- Step 1: Handle Actions and State Changes First ---
    # Check for the submission button press at the very beginning.
    if button(id: 'submit_reg', text: 'Complete Registration')
      # Re-fetch the current values from the state to validate them.
      current_name = @page_state.fetch('full_name', '')
      current_password = @page_state.fetch('password', '')

      # Clear previous errors
      @errors = {}

      # Perform validation
      @errors['full_name'] = 'Full Name cannot be empty.' if current_name.empty?
      @errors['password'] = 'Password must be at least 8 characters long.' if current_password.length < 8

      # If there are no errors, update the application's state.
      @submitted_successfully = true if @errors.empty?
    end

    # Handle the form reset action
    if button(id: 'reset_form', text: 'Reset Form')
      @submitted_successfully = false
      @errors = {}
    end

    # --- Step 2: Render the UI Based on the Current State ---
    if @submitted_successfully
      alert('Thank you for registering!', style: :success)
      p 'You can now reset the form to submit again.'
      # Render the reset button again in the success view
      button(id: 'reset_form', text: 'Reset Form')
    else
      # --- Form Inputs ---
      # These are now rendered *after* the validation logic has run.
      # They will correctly receive the @errors hash.
      form_group(label: 'Attendee Details') do
        full_name = text_input(id: 'full_name', label: 'Full Name:', error: @errors['full_name'])
        password = password_input(id: 'password', label: 'Create a password for your ticket:',
                                  error: @errors['password'])
        date_input(id: 'dob', label: 'Date of Birth:')
      end

      # ... (other form groups) ...

      # Render the submission button again in the form view
      button(id: 'submit_reg', text: 'Complete Registration')
    end

    divider
    h2 'Other Components...'
    # ... (rest of the app.rb file) ...
  end
  # ... (the /c page remains the same) ...
end
