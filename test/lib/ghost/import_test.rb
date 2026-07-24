require "test_helper"
require "tempfile"

class Ghost::ImportTest < ActiveSupport::TestCase
  SAMPLE = Rails.root.join("test/fixtures/files/ghost_export_sample.json").to_s

  setup do
    # Import into a clean slate so counts are deterministic.
    Tagging.delete_all
    ActionText::RichText.delete_all
    Post.delete_all
    Tag.delete_all
    @report = Ghost::Import.new(SAMPLE).run
  end

  test "imports the expected counts, splitting posts from pages" do
    assert_equal 2, @report.posts
    assert_equal 1, @report.pages
    assert_equal 2, @report.tags
    assert_equal 2, @report.taggings

    assert_equal 2, Post.articles.count
    assert_equal 1, Page.count
    assert_equal 2, Tag.count
    assert_equal 2, Tagging.count
  end

  test "prefers rendered html and normalises image URLs" do
    post = Post.find_by!(slug: "a-published-post")
    body = post.body.to_s

    assert_not body.include?("__GHOST_URL__")
    assert_not body.include?("nityesh.com")
    assert_not body.include?("/content/images/size/")
    assert_includes body, "/content/images/2024/01/pic.png"
    assert_equal "/content/images/2024/01/hero.png", post.feature_image
  end

  test "converts mobiledoc for rows with empty html and keeps raw source" do
    draft = Post.find_by!(slug: "a-draft-post")
    body  = draft.body.to_s

    assert_equal "draft", draft.status
    assert_includes body, "<hr>"
    assert_includes body, "/content/images/2024/02/draft.png"
    assert_includes body, "<code"
    assert_includes body, "puts 1"
    assert_includes body, "<strong>Bold</strong>"
    assert_equal 1, @report.converted_bodies
    assert draft.raw_source.present?, "raw mobiledoc retained"
    assert_includes draft.raw_source, "0.3.1"
  end

  test "maps excerpt and posts_meta onto the post" do
    post = Post.find_by!(slug: "a-published-post")
    assert_equal "The excerpt.", post.excerpt
    assert_equal "SEO Title", post.meta_title
    assert_equal "SEO description.", post.meta_description
    assert_equal "The hero caption", post.feature_image_caption
  end

  test "preserves Ghost timestamps" do
    post = Post.find_by!(slug: "a-published-post")
    assert_equal Time.utc(2024, 1, 2, 3, 4, 5), post.created_at
    assert_equal Time.utc(2024, 1, 3, 3, 4, 5), post.updated_at
    assert_equal Time.utc(2024, 1, 2, 9, 0, 0), post.published_at
  end

  test "strips a <style> block smuggled inside a Ghost HTML card at import" do
    export = {
      "db" => [ { "data" => {
        "tags"       => [],
        "posts"      => [ {
          "id" => "s1", "type" => "post", "status" => "published",
          "title" => "Kindle Highlights", "slug" => "kindle-highlights",
          "mobiledoc" => %({"version":"0.3.1","cards":[]}),
          "html" => "<p>Highlights from my Kindle.</p>" \
                    "<style>.bodyContainer { font-family: Arial; }\n.noteText { color: #333; }</style>" \
                    "<script>trackReading();</script>" \
                    "<p>Second highlight survives.</p>",
          "published_at" => "2024-01-02T09:00:00.000Z",
          "created_at" => "2024-01-02T03:04:05.000Z",
          "updated_at" => "2024-01-03T03:04:05.000Z"
        } ],
        "posts_meta" => [],
        "posts_tags" => []
      } } ]
    }
    file = Tempfile.new([ "export", ".json" ])
    file.write(export.to_json)
    file.close
    Ghost::Import.new(file.path).run

    body = Post.find_by!(slug: "kindle-highlights").body.to_s
    assert_includes body, "Highlights from my Kindle.", "surrounding prose survives"
    assert_includes body, "Second highlight survives.", "prose after the style block survives"
    assert_not_includes body, ".bodyContainer", "CSS selector text is gone"
    assert_not_includes body, "font-family", "CSS declaration text is gone"
    assert_not_includes body, "trackReading", "script text is gone"
  ensure
    file&.unlink
  end

  test "body_from_raw_source strips leaked CSS" do
    mobiledoc = {
      "version" => "0.3.1",
      "atoms"   => [],
      "markups" => [],
      "cards"   => [ [ "html", { "html" => "<style>.bodyContainer { color: #333; }</style><p>Kept prose.</p>" } ] ],
      "sections" => [ [ 10, 0 ] ]
    }.to_json

    body = Ghost::Import.body_from_raw_source(mobiledoc)

    assert_includes body, "Kept prose."
    assert_not_includes body, ".bodyContainer"
    assert_not_includes body, "color: #333"
  end

  test "is idempotent: re-running does not duplicate" do
    Ghost::Import.new(SAMPLE).run
    Ghost::Import.new(SAMPLE).run

    assert_equal 2, Post.articles.count
    assert_equal 1, Page.count
    assert_equal 2, Tag.count
    assert_equal 2, Tagging.count
  end
end
