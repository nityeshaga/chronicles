require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "resolving stamps the time and keeps the line; reopening clears both" do
    note = notes(:excerpt)
    note.resolve("Trimmed it.")
    assert note.resolved?
    assert_equal "Trimmed it.", note.resolution

    note.reopen
    assert_not note.resolved?
    assert_nil note.resolution
  end

  test "open and resolved are the two halves of the table" do
    assert_equal Note.count, Note.open.count + Note.resolved.count
    assert_includes Note.resolved, notes(:image)
    assert_includes Note.open, notes(:excerpt)
  end

  test "a note needs a page, an element and a body" do
    note = Note.new(user: users(:nityesh))
    assert_not note.valid?
    assert note.errors[:path].any? && note.errors[:selector].any? && note.errors[:body].any?

    note.assign_attributes(path: "about", selector: "p", body: "x")
    assert_not note.valid?, "a path must start at the site root"
  end

  test "deleting the author takes the notes along" do
    assert_difference -> { Note.count }, -Note.count do
      users(:nityesh).destroy
    end
  end
end
