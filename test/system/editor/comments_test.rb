require "editor_system_test_case"

# A doc's margin is drawn by the server and placed by JavaScript, and the placing is the
# feature: a comment sits beside the words it was left on. None of that is in the HTML the
# server sent, so it is driven in a real browser.
module Editor
  class CommentsTest < EditorSystemTestCase
    setup do
      sign_in_as users(:nityesh)
      visit edit_writing_doc_url(posts(:doc))
      assert_selector "lexxy-editor .lexxy-editor__content"
      # The margin has been measured once the fixture's open thread has somewhere to sit;
      # before that the editor is still mounting and would take a selection back.
      @card = find("##{dom_id(comments(:advisor))}")
      assert_eventually { @card[:style].to_s.include?("top:") }
    end

    test "an open thread is parked beside its passage, and the passage is tinted" do
      assert_text "Too abstract."

      passage = evaluate_script(<<~JS)
        (() => {
          const range = [ ...CSS.highlights.get("doc-comment") ][0]
          return { text: range.toString(), top: range.getBoundingClientRect().top }
        })()
      JS
      assert_equal "Think like a PhD advisor", passage["text"]
      assert_in_delta passage["top"], @card.rect.y, 2
    end

    test "selecting a passage and commenting on it" do
      select_text "what each unlocks"
      find(".doc-rail__add").click

      within ".comment-card--composer" do
        assert_selector "blockquote", text: "what each unlocks"
        fill_in "Comment", with: "Say what unlocking means."
        click_on "Comment"
      end

      assert_selector "[data-comments-target=thread] .comment__body", text: "Say what unlocking means."
      assert_no_selector ".comment-card--composer", visible: true
      thread = posts(:doc).comments.threads.ordered.last
      assert_equal "what each unlocks", thread.quote
      # The 32 characters before the passage: enough to tell this "unlocks" from another.
      assert_equal "ow the next three tutorials and ", thread.prefix
      assert_eventually { evaluate_script('CSS.highlights.get("doc-comment").size') == 2 }
    end

    test "replying, then resolving, then reopening" do
      within "##{dom_id(comments(:advisor))}" do
        fill_in "Reply", with: "Do the swap."
        click_on "Reply"
      end
      assert_selector "##{dom_id(comments(:advisor))} .comment", count: 3

      within("##{dom_id(comments(:advisor))}") { click_on "Resolve" }
      assert_no_selector "[data-comments-target=thread]"
      assert_eventually { !evaluate_script('CSS.highlights.has("doc-comment")') }

      find(".doc-rail__resolved summary", text: "2 resolved threads").click
      within("##{dom_id(comments(:advisor))}") { click_on "Reopen" }
      assert_selector "##{dom_id(comments(:advisor))}[data-comments-target=thread]"
      assert_eventually { evaluate_script('CSS.highlights.has("doc-comment")') }
    end

    test "a thread follows its words when the prose above it grows, and says so when they are gone" do
      before = @card.rect.y

      find(".lexxy-editor__content h2").click
      send_keys :home, "A new opening line.", :enter, "And another.", :enter
      assert_eventually { find("##{dom_id(comments(:advisor))}").rect.y > before + 20 }
      assert_no_selector "##{dom_id(comments(:advisor))}[data-orphaned]"

      select_text "PhD advisor"
      send_keys "good coach"
      assert_selector "##{dom_id(comments(:advisor))}[data-orphaned]"
      assert_selector "##{dom_id(comments(:advisor))} .comment-card__orphaned", text: "This text has changed"
    end

    test "a reply left over MCP arrives when the writer comes back to the tab" do
      Thread.current[:mcp_current_user] = users(:nityesh)
      AddCommentTool.new.call(doc: posts(:doc).id, body: "Swapped it for the five questions.", reply_to: comments(:advisor).id)
      AddCommentTool.new.call(doc: posts(:doc).id, body: "Which three?", quote: "next three tutorials")
      assert_no_text "Swapped it for the five questions."

      execute_script("window.dispatchEvent(new Event('focus'))")

      assert_selector "##{dom_id(comments(:advisor))} .comment__body", text: "Swapped it for the five questions."
      assert_selector "[data-comments-target=thread] .comment__body", text: "Which three?"
      assert_eventually { evaluate_script('CSS.highlights.get("doc-comment").size') == 2 }
    ensure
      Thread.current[:mcp_current_user] = nil
    end

    test "a half-written reply is never redrawn out from under the writer" do
      within("##{dom_id(comments(:advisor))}") { fill_in "Reply", with: "Half a thought" }
      Comment.create!(doc: posts(:doc), author_name: "Luo", body: "Arrived meanwhile.")

      execute_script("window.dispatchEvent(new Event('focus'))")

      assert_field "Reply", with: "Half a thought"
      assert_no_text "Arrived meanwhile."
    end

    test "typing a comment never reaches the doc's autosave" do
      select_text "what each unlocks"
      find(".doc-rail__add").click
      fill_in "Comment", with: "Half a thought"

      assert_selector ".editor-bar .autosave-status", text: "Saved"
      assert_no_selector ".editor-bar .autosave-status", text: "Saving"
    end

    private
      def dom_id(record) = ActionView::RecordIdentifier.dom_id(record)

      # A real selection over the first occurrence of some words in the prose, made the way
      # the browser reports any other: through the Selection API, announced by selectionchange.
      def select_text(words)
        execute_script(<<~JS, words)
          const content = document.querySelector(".lexxy-editor__content")
          const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT)
          for (let node = walker.nextNode(); node; node = walker.nextNode()) {
            const at = node.data.indexOf(arguments[0])
            if (at === -1) continue
            const range = document.createRange()
            range.setStart(node, at)
            range.setEnd(node, at + arguments[0].length)
            const selection = getSelection()
            selection.removeAllRanges()
            selection.addRange(range)
            break
          }
        JS
      end

      def assert_eventually(wait: Capybara.default_max_wait_time)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait
        until yield
          flunk "condition never became true" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep 0.05
        end
      end
  end
end
