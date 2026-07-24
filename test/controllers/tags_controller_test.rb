require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  test "shows a tag and its published posts" do
    get tag_url(tags(:chronicles).slug, trailing_slash: true)
    assert_response :success
    assert_select "h1", text: "chronicles"
    assert_select "h2", text: posts(:published).title
  end

  test "404s for an unknown tag" do
    get tag_url("nope", trailing_slash: true)
    assert_response :not_found
  end
end
