require "test_helper"

# The note itself is the gem's to test. What's ours: how it hangs off the author.
class Redpen::NoteTest < ActiveSupport::TestCase
  test "the author's notes are reachable from the author" do
    assert_equal Redpen::Note.count, users(:nityesh).notes.count
  end

  test "deleting the author takes the notes along" do
    assert_difference -> { Redpen::Note.count }, -Redpen::Note.count do
      users(:nityesh).destroy
    end
  end
end
