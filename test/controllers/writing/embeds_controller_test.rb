require "test_helper"

class Writing::EmbedsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    post writing_embeds_url, params: { url: "https://x.com/nityeshaga/status/123" }
    assert_redirected_to new_session_url
  end

  test "turns a tweet URL into an embed figure" do
    sign_in_as users(:nityesh)
    post writing_embeds_url, params: { url: "https://twitter.com/nityeshaga/status/123456" }
    assert_response :success
    assert_includes response.body, "twitter-tweet"
    assert_includes response.body, "kg-embed-card"
  end

  test "turns a YouTube URL into an iframe embed" do
    sign_in_as users(:nityesh)
    post writing_embeds_url, params: { url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }
    assert_response :success
    assert_includes response.body, "youtube.com/embed/dQw4w9WgXcQ"
  end

  test "rejects an unsupported URL" do
    sign_in_as users(:nityesh)
    post writing_embeds_url, params: { url: "https://example.com/nope" }
    assert_response :unprocessable_entity
  end
end
