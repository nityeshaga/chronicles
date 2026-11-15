require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "a reply joins its thread's doc" do
    reply = Comment.create!(parent: comments(:advisor), author_name: "Luo", body: "Done.")

    assert_equal posts(:doc), reply.doc
    assert_not reply.thread?
    assert_equal [ comments(:advisor_reply), reply ], comments(:advisor).replies.to_a
  end

  test "a reply answers the thread, not another reply" do
    reply = Comment.new(parent: comments(:advisor_reply), author_name: "Luo", body: "Nested.")

    assert_not reply.valid?
    assert reply.errors[:parent].any?
  end

  test "needs something said and someone saying it" do
    assert_not Comment.new(doc: posts(:doc), author_name: "Luo", body: "  ").valid?
    assert_not Comment.new(doc: posts(:doc), body: "Hello").valid?
  end

  test "the quote is stored as it reads, whatever whitespace the selection carried" do
    comment = Comment.create!(doc: posts(:doc), author_name: "Luo", body: "Hm.", quote: "  not a\n  syllabus. ")
    assert_equal "not a syllabus.", comment.quote
  end

  test "resolving and reopening" do
    thread = comments(:advisor)

    thread.resolve
    assert thread.resolved?
    assert_includes Comment.threads.resolved, thread

    thread.reopen
    assert_not thread.resolved?
    assert_includes Comment.threads.open, thread
  end

  test "is orphaned once the words it was left on are rewritten" do
    thread = comments(:advisor)
    assert_not thread.orphaned?

    posts(:doc).update!(body: "<p>Plan the way a good advisor would.</p>")
    assert thread.reload.orphaned?
  end

  test "a quote that runs across two blocks is still found" do
    thread = Comment.create!(doc: posts(:doc), author_name: "Luo", body: "Join these?", quote: "not a syllabus. Show the next")
    assert_not thread.orphaned?
  end

  test "a comment on no passage is never orphaned" do
    assert_not Comment.new(doc: posts(:doc), author_name: "Luo", body: "Overall: good.").orphaned?
  end

  test "deleting a thread deletes its replies" do
    assert_difference -> { Comment.count }, -2 do
      comments(:advisor).destroy
    end
  end
end
