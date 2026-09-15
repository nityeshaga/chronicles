require "test_helper"

class Writing::NotesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:nityesh) }

  test "the rail is the author's alone" do
    delete session_url
    get writing_notes_url(path: "/about/")
    assert_redirected_to new_session_url
  end

  test "index renders one page's notes inside the frame, with no layout" do
    get writing_notes_url(path: "/about/")
    assert_response :success
    assert_select "turbo-frame#notes"
    assert_select "header.masthead-print", count: 0
    assert_select "li.redpen-note", count: 2
    assert_select "li[data-note-selector='#{notes(:excerpt).selector}']"
    assert_select "li.redpen-note--resolved", text: /Swapped via update_post/
    assert_select "form.redpen-composer input[name='note[path]'][value='/about/']"
  end

  test "create stores the note and repaints the rail for that page" do
    assert_difference -> { Note.count }, 1 do
      post writing_notes_url, params: { note: { path: "/about/", selector: "#about > h1", snippet: "About", body: "Bigger." } }
    end
    assert_redirected_to writing_notes_url(path: "/about/")
    assert_equal users(:nityesh), Note.last.user
  end

  test "a blank note is dropped, not raised" do
    assert_no_difference -> { Note.count } do
      post writing_notes_url, params: { note: { path: "/about/", selector: "#about > h1", body: "" } }
    end
    assert_redirected_to writing_notes_url(path: "/about/")
  end

  test "destroy removes the note" do
    assert_difference -> { Note.count }, -1 do
      delete writing_note_url(notes(:excerpt))
    end
    assert_redirected_to writing_notes_url(path: "/about/")
  end

  test "resolve and reopen are create and destroy on the resolution" do
    note = notes(:excerpt)
    post writing_note_resolution_url(note), params: { resolution: "Done." }
    assert_redirected_to writing_notes_url(path: "/about/")
    assert note.reload.resolved?
    assert_equal "Done.", note.resolution

    delete writing_note_resolution_url(note)
    assert_not note.reload.resolved?
  end
end
