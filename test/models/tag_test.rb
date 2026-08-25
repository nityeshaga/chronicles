require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "generates a slug from the name" do
    tag = Tag.create!(name: "Deep Work")
    assert_equal "deep-work", tag.slug
  end

  test "has published posts through taggings" do
    assert_includes tags(:chronicles).posts, posts(:published)
  end

  test "tagging touches its post" do
    post = posts(:published)
    original = post.updated_at
    travel 1.second do
      Tagging.create!(post: post, tag: tags(:ai))
      assert post.reload.updated_at > original
    end
  end

  test "renaming a tag touches its posts so cached fragments and ETags refresh" do
    post = posts(:published)
    original = post.updated_at
    travel 1.second do
      tags(:chronicles).update!(name: "Chronicles Renamed")
      assert post.reload.updated_at > original
    end
  end

  # The touch is for caches, not for editors: nothing an open tab holds has changed, so
  # the lock stays where it was and the writer's next keystroke is not refused.
  test "renaming a tag leaves its posts' lock_version alone" do
    post = posts(:published)
    lock = post.lock_version

    tags(:chronicles).update!(name: "Chronicles Renamed")

    assert_equal lock, post.reload.lock_version
  end
end
