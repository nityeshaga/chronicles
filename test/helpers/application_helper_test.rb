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

  test "the time helpers are nil-safe" do
    assert_nil ghost_time(nil)
    assert_nil rss_time(nil)
  end
end
