require "test_helper"

class Writing::TagsControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get writing_tags_url
    assert_redirected_to new_session_url
  end

  test "index lists tags when signed in" do
    sign_in_as users(:nityesh)
    get writing_tags_url
    assert_response :success
    assert_select ".dash-row__title", text: "chronicles"
  end

  test "editing a tag's name and description without touching the slug" do
    sign_in_as users(:nityesh)
    tag = tags(:chronicles)
    patch writing_tag_url(tag), params: { tag: { name: "Chronicles", description: "Long reads." } }
    assert_redirected_to writing_tags_url
    assert_equal "Chronicles", tag.reload.name
    assert_equal "Long reads.", tag.description
  end

  test "editing a tag re-renders on a validation failure" do
    sign_in_as users(:nityesh)
    tag = tags(:chronicles)
    patch writing_tag_url(tag), params: { tag: { name: "" } }
    assert_response :unprocessable_entity
    assert_select "ul.errors"
  end

  # --- Minting: a deliberate act in its own form. Create-or-find the tag, attach it to
  #     the post being edited, and stream the refreshed checkbox list back. ---
  test "minting a new tag creates it and attaches it to the post" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    assert_difference -> { Tag.count }, 1 do
      post writing_tags_url, params: { tag_name: "Field Notes", post_id: draft.slug },
        as: :turbo_stream
    end
    assert_includes draft.reload.tags.map(&:slug), "field-notes"
    assert_match "post_tags", response.body
  end

  test "minting reuses an existing tag rather than duplicating it" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    assert_no_difference -> { Tag.count } do
      post writing_tags_url, params: { tag_name: "chronicles", post_id: draft.slug },
        as: :turbo_stream
    end
    assert_includes draft.reload.tags, tags(:chronicles)
  end

  test "minting a blank name is a no-op" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    assert_no_difference -> { Tag.count } do
      post writing_tags_url, params: { tag_name: "  ", post_id: draft.slug }, as: :turbo_stream
    end
  end

  test "minting a name that parameterizes to an empty slug is a no-op" do
    sign_in_as users(:nityesh)
    draft = posts(:draft)
    assert_no_difference -> { Tag.count } do
      post writing_tags_url, params: { tag_name: "???", post_id: draft.slug }, as: :turbo_stream
    end
    assert_response :success
  end

  test "minting against an unknown post is unprocessable" do
    sign_in_as users(:nityesh)
    assert_no_difference -> { Tag.count } do
      post writing_tags_url, params: { tag_name: "Field Notes", post_id: "no-such-post" },
        as: :turbo_stream
    end
    assert_response :unprocessable_entity
  end
end
