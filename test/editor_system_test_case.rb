require "test_helper"

# The writing room's keyboard behaviours — bubble, slash menu, hotkeys — exist only once
# JavaScript runs, so this lane drives a real browser. rack_test
# (ApplicationSystemTestCase) stays the default for every server-rendered flow; reach for
# this class only when the thing under test is not in the HTML the server sent.
class EditorSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  def sign_in_as(user)
    visit new_session_url
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "secret123"
    click_on "Sign in"
  end

  def open_editor(post)
    visit edit_writing_post_url(post)
    assert_selector "lexxy-editor .lexxy-editor__content"
    find(".lexxy-editor__content").click
  end
end
