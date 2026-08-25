require "editor_system_test_case"

class SelectionBubbleTest < EditorSystemTestCase
  test "selecting words offers the formats, and Bold applies to them" do
    sign_in_as users(:nityesh)
    open_editor posts(:draft)

    find(".lexxy-editor__content").send_keys "Asymmetry is the whole game."
    5.times { find(".lexxy-editor__content").send_keys [ :shift, :left ] }

    assert_selector ".selection-bubble [data-for=bold]"
    find(".selection-bubble [data-for=bold]").click

    assert_selector ".lexxy-editor__content strong", text: "game."
  end
end
