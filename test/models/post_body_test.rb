require "test_helper"

# The blank paragraphs a body collects at its edges go at save, whoever saved it; the ones
# in the middle are the writer's.
class PostBodyTest < ActiveSupport::TestCase
  test "blank paragraphs at either end are trimmed on save" do
    post = Post.create!(title: "Trimmed", body: "<p><br></p><p></p><p>&nbsp;</p><p>kept</p><p> </p><p><br></p>")
    assert_equal "<p>kept</p>", post.reload.body.body.to_html
  end

  test "a blank paragraph between two others is kept" do
    post = Post.create!(title: "Spaced", body: "<p>one</p><p><br></p><p>two</p>")
    assert_equal "<p>one</p><p><br></p><p>two</p>", post.reload.body.body.to_html
  end

  test "a body that is nothing but blank paragraphs saves as blank" do
    post = Post.create!(title: "Empty", body: "<p><br></p><p><br></p>")
    assert post.reload.body.blank?
  end

  # A paragraph holding something a reader can see is not blank, whatever else it holds.
  test "a paragraph carrying an image is not blank" do
    post = Post.create!(title: "Pictured", body: %(<p><br></p><p><img src="/x.png"></p>))
    assert_equal %(<p><img src="/x.png"></p>), post.reload.body.body.to_html
  end

  test "the trim applies on a later save of the body too" do
    post = Post.create!(title: "Later", body: "<p>first</p>")
    post.update!(body: "<p>first</p><p>second</p><p><br></p>")
    assert_equal "<p>first</p><p>second</p>", post.reload.body.body.to_html
  end

  test "Post::Body.trim answers what a body would save as" do
    assert_equal "<p>a</p><p><br></p><p>b</p>", Post::Body.trim("<p><br></p>\n<p>a</p><p><br></p><p>b</p>\n<p></p>")
    assert_equal "", Post::Body.trim("<p><br></p>")
    assert_equal "", Post::Body.trim(nil)
  end
end
