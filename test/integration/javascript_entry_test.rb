require "test_helper"

# Readers never download the editor. The public layout imports the "application" entry,
# whose preloads stop at Turbo, Stimulus and the public controllers; the writing layout
# imports "writing", which is the only module that pulls Lexxy in.
class JavascriptEntryTest < ActionDispatch::IntegrationTest
  test "a public post ships no editor" do
    get post_url(posts(:published), trailing_slash: true)
    assert_response :success

    assert_select "script[type=module]", text: 'import "application"'
    assert_select "script[type=module]", text: 'import "writing"', count: 0
    assert_select "link[rel=modulepreload][href*=lexxy]", count: 0
    assert_select "link[rel=modulepreload][href*=activestorage]", count: 0
    assert_select "link[rel=modulepreload][href*='/writing/']", count: 0
    assert_select "link[rel=modulepreload][href*='/controllers/reveal_controller']"
  end

  test "the writing room imports the editor" do
    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:published))
    assert_response :success

    assert_select "script[type=module]", text: 'import "writing"'
    assert_select "link[rel=modulepreload][href*='/lexxy.min-']"
    assert_select "link[rel=modulepreload][href*=lexxy_embed_frames]"
    assert_select "link[rel=modulepreload][href*='/writing/autosave_controller']"
  end

  test "the preview keeps the public entry even when signed in" do
    sign_in_as users(:nityesh)
    get writing_post_url(posts(:published))
    assert_response :success

    assert_select "script[type=module]", text: 'import "application"'
    assert_select "link[rel=modulepreload][href*=lexxy]", count: 0
  end
end
