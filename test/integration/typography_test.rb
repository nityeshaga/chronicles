require "test_helper"

# The canvas is the page: the writing layout loads the reader's typefaces through the
# same <link> the public layout does, so the editor can't render a post in a face the
# published page never sees (it used to load EB Garamond and fall back to it).
class TypographyTest < ActionDispatch::IntegrationTest
  FONTS = "link[rel=stylesheet][href^='https://fonts.googleapis.com/css2']"

  test "the writing room loads the reader's fonts" do
    get post_url(posts(:published), trailing_slash: true)
    reader_fonts = css_select(FONTS).map { |link| link["href"] }
    assert_equal 1, reader_fonts.size
    assert_match(/Fraunces.*Newsreader.*IBM\+Plex\+Mono/, reader_fonts.first)

    sign_in_as users(:nityesh)
    get edit_writing_post_url(posts(:published))
    writer_fonts = css_select(FONTS).map { |link| link["href"] }

    assert_includes writer_fonts, reader_fonts.first
    assert_not writer_fonts.any? { |href| href.include?("Garamond") }
  end
end
