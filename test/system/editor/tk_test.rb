require "editor_system_test_case"

# TK reminders: Koenig's rule, a marker in the gutter, and a warning that never blocks.
module Editor
  class TkTest < EditorSystemTestCase
    # click_on returns before the sign-in redirect has landed, so anything that visits
    # straight after it races the session cookie and bounces back to the door. Wait for
    # the room. (EditorSystemTestCase is byte-identical across the Phase 2 branches, so
    # the wait belongs here rather than in it.)
    setup do
      sign_in_as users(:nityesh)
      assert_selector ".writing-dash"
    end

    test "a TK in the body is marked, counted, and warned about before publishing" do
      open_editor posts(:draft)
      assert_no_selector ".tk-marker"

      find(".lexxy-editor__content").send_keys(:end, " The figure was TK.")
      assert_selector ".tk-marker", count: 1

      find(".editor-bar__publish").click
      assert_selector ".publish-note", text: "1 TK remains"
      # A warning, not a gate: Ghost ships posts with TKs in them and so does this.
      assert_selector "input[type=submit][value=Publish]:not([disabled])"
    end

    test "the title is counted alongside the body, and the note pluralises" do
      open_editor posts(:draft)
      find(".lexxy-editor__content").send_keys(:end, " Two of them: TK and TK.")
      find(".editor-canvas__title").send_keys(" TK")

      assert_selector ".tk-marker", count: 2
      find(".editor-bar__publish").click
      assert_selector ".publish-note", text: "3 TKs remain"
    end

    test "TK inside a word is a word" do
      open_editor posts(:draft)
      find(".lexxy-editor__content").send_keys(:end, " Atkins wrote tks about stkz.")

      assert_no_selector ".tk-marker"
      find(".editor-bar__publish").click
      assert_no_selector ".publish-note", text: /TK/
    end
  end
end
