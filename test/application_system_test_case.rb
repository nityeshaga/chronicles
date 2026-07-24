require "test_helper"

# Driven by rack_test: the writing flows under test (sign in, save, publish,
# unpublish, preview) are all plain server-rendered forms, so they exercise
# end-to-end without a browser — fast and deterministic on the always-on box.
# JS behaviours (Lexxy, autosave/embed Stimulus) are covered by unit + integration
# tests and the Phase 3 manual exit check.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

  def sign_in_as(user)
    visit new_session_url
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "secret123"
    click_on "Sign in"
  end
end
