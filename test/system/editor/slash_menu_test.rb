require "editor_system_test_case"

# The trigger rule is the whole feature: a "/" that starts an empty line is a menu, and a
# "/" anywhere else is a slash. Everything below drives the real editor, because none of
# it exists in the HTML the server sent.
class SlashMenuTest < EditorSystemTestCase
  # An empty canvas, on a full page load. Clicking "New post" from the dashboard would be
  # the writer's route, and on `main` today it lands on a dead editor: a Turbo visit
  # inserts <lexxy-editor> with its <lexxy-toolbar> child in one go, custom elements
  # upgrade parents first, and the editor throws attaching a toolbar that isn't a toolbar
  # yet. A full load has the parser build the tree before Lexxy defines either element, so
  # they upgrade in registration order and the editor comes up. Reported separately; when
  # it's fixed, this can go back to clicking.
  setup do
    sign_in_as users(:nityesh)
    visit new_writing_post_url
    assert_selector "lexxy-editor .lexxy-editor__content"
    body.click
  end

  test "a slash on an empty line makes the block the writer names" do
    body.send_keys "/qu"
    assert_selector ".slash-menu [aria-selected=true]", text: "Quote"

    body.send_keys :enter
    body.send_keys "Set apart"

    assert_selector ".lexxy-editor__content blockquote", text: "Set apart"
    assert_no_selector ".slash-menu"
    assert_not_includes body.text, "/"
  end

  # Both halves in one test on purpose: "no menu here" passes just as well when the
  # JavaScript never loaded, so it only means anything next to a "menu there".
  test "a slash inside a sentence is a slash" do
    body.send_keys "and/or"
    assert_no_selector ".slash-menu"

    body.send_keys :enter
    body.send_keys "/qu"

    assert_selector ".slash-menu [aria-selected=true]", text: "Quote"
  end

  test "escape closes the menu and leaves what was typed alone" do
    body.send_keys "/qu"
    assert_selector ".slash-menu"

    body.send_keys :escape

    assert_no_selector ".slash-menu"
    assert_includes body.text, "/qu"
  end

  test "the embed row takes the link typed after the word" do
    body.send_keys "/youtube https://youtu.be/dQw4w9WgXcQ"
    assert_selector ".slash-menu [role=option]", text: "Embed", count: 1

    body.send_keys :enter

    assert_selector ".lexxy-editor__content action-text-attachment[content-type='text/html'] iframe"
  end

  private
    def body
      find(".lexxy-editor__content")
    end
end
