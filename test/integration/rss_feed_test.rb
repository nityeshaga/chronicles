require "test_helper"

# RSS shape parity with Ghost's /rss/ (reference/rss.xml): full content, stable guids,
# categories, feature-image enclosure, GMT dates — so feed readers don't re-mark items.
class RssFeedTest < ActionDispatch::IntegrationTest
  setup do
    get "/rss/"
    assert_response :success
    @doc = Nokogiri::XML(response.body)
    assert_empty @doc.errors, "RSS must be well-formed XML"
    @doc.remove_namespaces!
  end

  test "channel carries the site identity and self link" do
    assert_equal Setting.current.site_title, @doc.at_xpath("//channel/title").text
    assert_equal Setting.current.site_description, @doc.at_xpath("//channel/description").text
    assert_equal "http://www.example.com/", @doc.at_xpath("//channel/link").text
    assert_equal "60", @doc.at_xpath("//channel/ttl").text
    assert @doc.at_xpath("//channel/lastBuildDate").text.end_with?("GMT")
  end

  test "item uses a stable non-permalink guid (the Ghost id)" do
    post = posts(:published)
    guid = @doc.at_xpath("//item/guid")
    assert_equal post.ghost_id, guid.text
    assert_equal "false", guid["isPermaLink"]
  end

  test "item carries category, creator, GMT pubDate, media and full content" do
    post = posts(:published)
    item = @doc.at_xpath("//item[guid='#{post.ghost_id}']")

    assert_equal post.title, item.at_xpath("title").text
    assert_equal "chronicles", item.at_xpath("category").text
    assert_equal Setting.current.author_name, item.at_xpath("creator").text
    assert item.at_xpath("pubDate").text.end_with?("GMT")

    media = item.at_xpath("content")   # media:content, namespaces stripped
    assert_equal "http://www.example.com#{post.feature_image}", media["url"]

    encoded = item.at_xpath("encoded").text   # content:encoded
    assert_includes encoded, "published"                              # the body
    assert_includes encoded, "<img src=\"http://www.example.com#{post.feature_image}\""  # prepended feature image
  end

  test "drafts never appear in the feed" do
    assert_nil @doc.at_xpath("//item[title=#{quote(posts(:draft).title)}]")
  end

  private
    def quote(str) = "'#{str}'"
end
