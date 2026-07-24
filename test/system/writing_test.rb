require "application_system_test_case"

class WritingTest < ApplicationSystemTestCase
  test "signing in, writing a post, and publishing it" do
    sign_in_as users(:nityesh)
    assert_text "Writing"

    click_on "New post"
    fill_in "Title", with: "A System-Tested Post"
    click_on "Save draft"

    # Landed on the editor for the new draft.
    assert_field "Title", with: "A System-Tested Post"
    post = Post.find_by!(slug: "a-system-tested-post")
    assert post.draft?

    # The publish control lives in its own popover; the schedule form publishes now
    # when its time is left blank.
    within ".publish-popover" do
      click_on "Publish"
    end
    assert post.reload.published?

    # It now renders on its public URL.
    visit post_path(post)
    assert_text "A System-Tested Post"
  end

  test "unpublishing returns a post to the drafts list" do
    sign_in_as users(:nityesh)
    published = posts(:published)

    visit edit_writing_post_url(published)
    within ".publish-popover" do
      click_on "Unpublish"
    end

    assert published.reload.draft?
  end

  test "the dashboard lists drafts before published posts" do
    sign_in_as users(:nityesh)
    visit writing_posts_url

    # Filter tabs replace the old stacked sections.
    assert_selector ".dash-tab", text: /Drafts/
    assert_selector ".dash-tab", text: /Published/
    assert_link "A Draft Post"

    # One list, drafts first (no scheduled posts in the fixtures).
    titles = all(".dash-row__title").map(&:text)
    assert_operator titles.index("A Draft Post"), :<, titles.index("A Published Post")
  end

  test "reaching Connect from the dashboard and minting a token" do
    sign_in_as users(:nityesh)
    visit writing_posts_url
    click_on "Connect"

    assert_selector "h2", text: "Claude Code"
    assert_text "claude mcp add"

    fill_in "Name a new token", with: "System Test Token"
    click_on "Create token"

    assert_text "copy it now"
    assert_selector ".dash-row__title", text: "System Test Token"
  end
end
