require "test_helper"

class DocTest < ActiveSupport::TestCase
  test "can't be published, by any of the publishing verbs" do
    doc = posts(:doc)

    assert_not doc.publish
    assert_includes doc.errors.full_messages.to_sentence, "private"
    assert_not doc.publish(at: 2.days.from_now)
    assert_raises(ActiveRecord::RecordInvalid) { doc.publish_now }
    assert doc.reload.draft?
    assert_nil doc.published_at
  end

  test "is never among what a reader may see, even signed in" do
    assert_not_includes Post.viewable(writer: false), posts(:doc)
    assert_not_includes Post.viewable(writer: true), posts(:doc)
  end

  test "stays unread even if a published row were ever typed as a doc" do
    posts(:published).update_column(:type, "Doc")

    assert_not_includes Post.viewable(writer: false), Post.find(posts(:published).id)
    assert_not_includes Post.viewable(writer: true), Post.find(posts(:published).id)
  end

  test "is addressed by id, so a retitle never moves it" do
    doc = posts(:doc)
    assert_equal doc.id.to_s, doc.to_param

    doc.update!(title: "Something else entirely")
    assert_equal doc.id.to_s, doc.to_param
  end

  test "answers the editor's questions as a doc" do
    doc = posts(:doc)

    assert doc.commentable?
    assert_not doc.publishable?
    assert_not doc.taggable?
    assert_equal "doc", doc.dashboard_bucket
    assert posts(:draft).publishable?
    assert_not posts(:draft).commentable?
  end

  test "takes its comments with it" do
    assert_difference -> { Comment.count }, -3 do
      posts(:doc).destroy
    end
  end
end
