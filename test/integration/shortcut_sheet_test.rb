require "test_helper"

# The toolbar declares the hotkeys and the sheet prints them — one fact in two places, and
# the failure mode is silent: a key that works but is written down nowhere, or a key the
# sheet promises after the button stopped declaring it. This holds the two together.
class ShortcutSheetTest < ActionDispatch::IntegrationTest
  MODIFIER_SYMBOLS = { "cmd" => "⌘", "ctrl" => "⌃", "alt" => "⌥", "shift" => "⇧" }

  test "the sheet prints every hotkey the toolbar declares" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:draft))
    assert_response :success

    printed = css_select(".shortcut-sheet kbd").map(&:text)
    buttons = css_select("lexxy-toolbar [data-hotkey]")
    assert printed.any?, "the shortcut sheet printed no keys at all"
    assert buttons.any?, "the toolbar declared no hotkeys, so this test proved nothing"

    buttons.each do |button|
      # A button declares the same chord once per platform ("cmd+e ctrl+e"); the sheet is
      # written in Mac symbols and says so in its foot, so printing any one of them counts.
      combinations = button["data-hotkey"].split.map { |combination| symbolize(combination) }

      assert combinations.intersect?(printed),
        "the toolbar's #{button["name"]} answers to #{combinations.join(" / ")} and the sheet prints none of them"
    end
  end

  private
    # "cmd+shift+x" is ⌘⇧X on the sheet, which is how the button's own title spells it.
    def symbolize(combination)
      *modifiers, key = combination.split("+")
      modifiers.map { |modifier| MODIFIER_SYMBOLS.fetch(modifier) }.join + key.upcase
    end
end
