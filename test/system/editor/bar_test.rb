require "editor_system_test_case"

# The editor bar: what it says about the post once the canvas has scrolled away from
# under it, and what it says about the writer's work while a save is in the air.
module Editor
  class BarTest < EditorSystemTestCase
    # click_on returns before the sign-in redirect has landed, so anything that visits
    # straight after it races the session cookie and bounces back to the door. Wait for
    # the room. (EditorSystemTestCase is byte-identical across the Phase 2 branches, so
    # the wait belongs here rather than in it.)
    setup do
      sign_in_as users(:nityesh)
      assert_selector ".writing-dash"
    end

    test "the title moves into the bar once the canvas title has gone under it" do
      open_editor posts(:draft)
      assert_no_selector ".editor-bar__title", text: posts(:draft).title

      find(".lexxy-editor__content").send_keys("A line of prose.\n" * 25)
      scroll_to 0, 600
      assert_selector ".editor-bar__title", text: posts(:draft).title

      scroll_to 0, 0
      assert_no_selector ".editor-bar__title", text: posts(:draft).title
    end

    test "the bar counts the words and the minutes they take to read" do
      open_editor posts(:published)
      assert_selector ".editor-bar__count", text: /\d+ words · \d+ min/

      words = find(".editor-bar__count").text[/[\d,]+/].delete(",").to_i
      find(".lexxy-editor__content").send_keys(:end, " one two three four five")

      assert_selector ".editor-bar__count", text: "#{words + 5} words"
    end

    # C12. The bug was that #run set the status from the response, so a keystroke landing
    # during the fetch said "Unsaved changes" and the reply then painted "Saved" over it —
    # the bar reporting the network while the canvas held work no save was holding. The trap
    # types on top of the save the instant it goes out, which is the race made deliberate.
    test "a landed save doesn't say Saved while a keystroke is still unsaved" do
      open_editor posts(:draft)
      page.execute_script <<~JS
        const status = document.querySelector(".editor-bar .autosave-status")
        const title = document.querySelector(".editor-canvas__title")
        let sprung = false

        new MutationObserver(() => {
          if (status.dataset.state !== "saving" || sprung) return
          sprung = true
          title.value += "!"
          title.dispatchEvent(new Event("input", { bubbles: true }))
          setTimeout(() => document.body.dataset.barVerdict = status.dataset.state, 800)
        }).observe(status, { attributes: true, childList: true, subtree: true, characterData: true })
      JS

      find(".lexxy-editor__content").send_keys(:end, " Something worth saving.")

      # The trap springs on the first save, two seconds in, and reports 800ms later; the
      # save after it lands two seconds after that. Both are past Capybara's default wait.
      assert_selector "body[data-bar-verdict='unsaved']", wait: 8
      assert_selector ".editor-bar .autosave-status[data-state='saved']", wait: 8
    end
  end
end
