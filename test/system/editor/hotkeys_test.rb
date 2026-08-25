require "editor_system_test_case"

# The keys, in a browser, because none of this exists until JavaScript runs.
class HotkeysTest < EditorSystemTestCase
  test "⌘⌥2 raises the line to a heading and ⌘⌥0 puts it back" do
    open_editor_as posts(:draft)

    body.send_keys "A line worth raising"
    body.send_keys [ :meta, :alt, "2" ]
    assert_selector ".lexxy-editor__content h2", text: "A line worth raising"

    body.send_keys [ :meta, :alt, "0" ]
    assert_selector ".lexxy-editor__content p", text: "A line worth raising"
    assert_no_selector ".lexxy-editor__content h2"
  end

  # What a Mac keyboard really sends: Option turns the character into a symbol, so
  # event.key reads "™" and only event.code still names the key that was pressed.
  # WebDriver's synthetic chord above reports the plain digit, so it happens to exercise
  # the same branch — this one is the shape a writer's hands produce.
  test "the ⌥2 a Mac keyboard sends — key ™, code Digit2 — raises the heading too" do
    open_editor_as posts(:draft)

    body.send_keys "Option really is a dead key"
    press_option_digit key: "™", code: "Digit2"
    assert_selector ".lexxy-editor__content h2", text: "Option really is a dead key"
  end

  test "⌘⇧P opens publishing" do
    open_editor_as posts(:draft)

    body.send_keys [ :meta, :shift, "p" ]
    assert_selector ".publish-popover.is-open"
  end

  test "⌘/ opens the shortcut sheet" do
    open_editor_as posts(:draft)

    body.send_keys [ :meta, "/" ]
    assert_selector "dialog.shortcut-sheet[open]", text: "Keyboard shortcuts"
  end

  test "a panel takes focus while it is open and hands it back when it closes" do
    open_editor_as posts(:draft)

    click_on "Settings"
    assert_selector ".settings-panel.is-open"
    assert focused_within?(".settings-panel"), "opening the panel left focus outside it"

    find("body").send_keys :escape
    assert_no_selector ".settings-panel.is-open"
    assert_equal "Settings", evaluate_script("document.activeElement.textContent").strip
  end

  private
    # sign_in_as clicks and returns without waiting for the answer, so the dashboard is
    # what says the session exists; without it the next visit can race the sign-in and
    # land back on the door.
    def open_editor_as(post)
      sign_in_as users(:nityesh)
      assert_selector ".writing-dash"
      open_editor post
    end

    def body
      find(".lexxy-editor__content")
    end

    def press_option_digit(key:, code:)
      execute_script(<<~JS, key, code)
        document.querySelector(".lexxy-editor__content").dispatchEvent(new KeyboardEvent("keydown", {
          key: arguments[0], code: arguments[1], metaKey: true, altKey: true, bubbles: true, cancelable: true
        }))
      JS
    end

    def focused_within?(selector)
      evaluate_script("!!document.activeElement.closest(#{selector.to_json})")
    end
end
