require "test_helper"

# The public blog is a read surface: it must serve everyone, including old browsers.
# Only the Writing:: editor (Lexxy) needs modern browser APIs, so the allow_browser
# gate lives on Writing::BaseController — not ApplicationController, where it 406'd
# public readers site-wide (invisible in Search Console, since crawlers send no version).
class BrowserGateTest < ActionDispatch::IntegrationTest
  # iOS 16 Safari — below the :modern threshold, so allow_browser blocks it.
  OLD_BROWSER = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) " \
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"

  test "an old browser still reads a public post" do
    get post_url(posts(:published), trailing_slash: true), headers: { "User-Agent" => OLD_BROWSER }
    assert_response :success
  end

  test "an old browser is turned away from the writing editor" do
    sign_in_as users(:nityesh)
    get writing_posts_url, headers: { "User-Agent" => OLD_BROWSER }
    assert_response :not_acceptable
  end
end
