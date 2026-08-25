require "editor_system_test_case"

# TK reminders: Koenig's rule, a marker in the gutter, and a warning that never blocks.
module Editor
  class TkTest < EditorSystemTestCase
    setup { sign_in_as users(:nityesh) }

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
      find(".lexxy-editor__content").send_keys(:end, " Atkins wrote tks about stkz, but the date is TK.")

      # The real TK is what makes the four negatives mean anything: without it this passes
      # just as well against a matcher that has stopped matching altogether.
      assert_selector ".tk-marker", count: 1
      find(".editor-bar__publish").click
      assert_selector ".publish-note", text: "1 TK remains"
    end

    # The popover is server-rendered chrome that only a saved record wears, and it arrives
    # — and comes back on every rename — as a morph of #editor-overlays carrying the note
    # hidden with an empty count. None of that is a keystroke, so nothing here would
    # rescan: the warning would be silent on the flow that starts every post.
    test "a draft minted with a TK in it warns without another keystroke" do
      mint_a_draft_holding_a_tk

      find(".editor-bar__publish").click
      assert_selector ".publish-note", text: "1 TK remains"
    end

    # A rename is answered with the same morph the mint sent, so the note goes hidden and
    # empty again — and on a fresh draft, whose slug still follows the title, every title
    # edit is a rename. Asserting on the note has to wait for that morph or it reads the
    # state before it, which passes whether the rescan happens or not.
    test "a rename doesn't take the warning away with it" do
      mint_a_draft_holding_a_tk
      find(".editor-bar__publish").click
      assert_selector ".publish-note", text: "1 TK remains"

      page.execute_script <<~JS
        addEventListener("turbo:before-stream-render",
          () => setTimeout(() => document.body.dataset.renamed = "true", 600), { once: true })
      JS
      find(".editor-canvas__title").send_keys(" renamed")

      assert_selector "body[data-renamed='true']", wait: 10
      assert_selector ".publish-note", text: "1 TK remains"
    end

    private
      # The one flow that has no persisted record to open: a blank canvas typed into until
      # autosave mints the draft and streams in the chrome only a saved post wears.
      def mint_a_draft_holding_a_tk
        visit new_writing_post_url
        assert_selector "lexxy-editor .lexxy-editor__content"

        find(".editor-canvas__title").send_keys("A fresh one")
        find(".lexxy-editor__content").click
        find(".lexxy-editor__content").send_keys("The figure was TK.")
        assert_selector ".editor-bar__publish", wait: 8
      end
  end
end
