require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # ghost_time/rss_time force .utc, so setting config.time_zone = "Asia/Kolkata"
  # must NOT shift the meta/JSON-LD/sitemap or RSS timestamps: they stay UTC.
  test "ghost_time emits UTC regardless of the application zone" do
    assert_equal "Asia/Kolkata", Time.zone.name
    assert_equal "2025-01-02T19:30:00.000Z", ghost_time(Time.utc(2025, 1, 2, 19, 30))
  end

  test "rss_time emits a GMT wall clock regardless of the application zone" do
    assert_equal "Thu, 02 Jan 2025 19:30:00 GMT", rss_time(Time.utc(2025, 1, 2, 19, 30))
  end

  # One speed, one count. If the bar ever divided by its own 265 the two surfaces would
  # drift a minute apart on a long post and nothing would fail.
  test "reading time is the word count at the one reading speed" do
    post = posts(:published)
    assert_equal (word_count(post) / ApplicationHelper::READING_SPEED.to_f).ceil, reading_time(post)
  end

  test "word count reads the words, not the markup" do
    post = posts(:published)
    post.body = "<p>One <strong>two</strong> three</p>"
    assert_equal 3, word_count(post)
    assert_equal 1, reading_time(post)
  end

  # A body with nothing in it still reads as a minute — "0 min read" is not a thing.
  test "reading time floors at one minute" do
    post = posts(:published)
    post.body = ""
    assert_equal 0, word_count(post)
    assert_equal 1, reading_time(post)
  end

  test "the time helpers are nil-safe" do
    assert_nil ghost_time(nil)
    assert_nil rss_time(nil)
  end
end
