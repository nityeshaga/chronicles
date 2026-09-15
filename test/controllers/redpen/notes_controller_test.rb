require "test_helper"

# The engine's controllers inherit ours, so the pen sits behind the same sign-in as the
# writing room, and the author it records is Current.user.
class Redpen::NotesControllerTest < ActionDispatch::IntegrationTest
  # Spelled out: see RedpenRailTest.
  def redpen_notes_path(path) = "/writing/redpen/notes?path=#{ERB::Util.url_encode(path)}"

  test "the rail is the author's alone" do
    get redpen_notes_path("/about/")
    assert_redirected_to "/session/new"
  end

  test "index renders one page's notes inside the frame, with no layout" do
    sign_in_as users(:nityesh)
    get redpen_notes_path("/about/")
    assert_response :success
    assert_select "turbo-frame#redpen_notes"
    assert_select "header.masthead-print", count: 0
    assert_select "li.redpen-note", count: 2
    assert_select "li.redpen-note--resolved", text: /Swapped via update_post/
  end

  test "a new note belongs to the signed-in author" do
    sign_in_as users(:nityesh)
    assert_difference -> { Redpen::Note.count }, 1 do
      post "/writing/redpen/notes", params: { note: { path: "/about/", selector: "#about > h1", snippet: "About", body: "Bigger." } }
    end
    assert_redirected_to redpen_notes_path("/about/")
    assert_equal users(:nityesh), Redpen::Note.last.author
  end
end
