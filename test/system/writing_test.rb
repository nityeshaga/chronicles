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

  test "deleting a post from the editor" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)

    visit edit_writing_post_url(draft)
    # The button lives in the settings panel and submits the sibling #delete-post form
    # via its form attribute.
    click_on "Delete post"

    assert_current_path writing_root_path
    assert_not Post.exists?(draft.id)
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

  test "the dashboard puts the last thing touched first, whatever kind it is" do
    sign_in_as users(:nityesh)
    posts(:published).touch
    visit writing_posts_url

    # Filter tabs replace the old stacked sections.
    assert_selector ".dash-tab", text: /Drafts/
    assert_selector ".dash-tab", text: /Published/
    assert_link "A Draft Post"

    # One list for every tab, so drafts and published interleave in true edit order: the
    # post just touched leads, ahead of a draft that is otherwise newer.
    titles = all(".dash-row__title").map(&:text)
    assert_equal "A Published Post", titles.first
    assert_operator titles.index("A Published Post"), :<, titles.index("A Draft Post")
  end

  test "reaching Connect from the dashboard and minting a token" do
    sign_in_as users(:nityesh)
    visit writing_posts_url
    # Connect lives in the account menu, a native <details> the rack_test driver can't
    # open (no JavaScript, and it doesn't act on summary clicks), so reach the link
    # where it sits rather than through the disclosure.
    find(".dash-menu a", text: "Connect", visible: :all).click

    assert_selector "h2", text: "Claude Code"
    assert_text "claude mcp add"

    fill_in "Name a new token", with: "System Test Token"
    click_on "Create token"

    assert_text "copy it now"
    assert_selector ".dash-row__title", text: "System Test Token"
  end
end
