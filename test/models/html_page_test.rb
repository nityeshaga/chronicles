require "test_helper"

class HtmlPageTest < ActiveSupport::TestCase
  DOCUMENT = "<!DOCTYPE html>\n<html lang=\"en\"><head><title>Landing</title></head><body>hi</body></html>\n"

  test "a complete document saves" do
    page = HtmlPage.create!(title: "Landing", raw_html: DOCUMENT)
    assert page.persisted?
    assert_equal DOCUMENT, page.reload.raw_html
  end

  test "a fragment is rejected — it would publish as a broken white page" do
    page = HtmlPage.new(title: "Fragment", raw_html: "<div><h1>Just a chunk</h1></div>")
    assert_not page.valid?
    assert_includes page.errors[:raw_html].to_s, "complete HTML document"
  end

  test "an unclosed document is rejected" do
    assert_not HtmlPage.new(title: "Truncated", raw_html: "<html><body>cut off mid-").valid?
  end

  test "blank raw_html is rejected" do
    page = HtmlPage.new(title: "Empty", raw_html: "")
    assert_not page.valid?
    assert_includes page.errors[:raw_html], "can't be blank"
  end

  test "the document tags are matched case-insensitively" do
    assert HtmlPage.new(title: "Shouty", raw_html: "<HTML><BODY>hi</BODY></HTML>").valid?
  end

  test "articles excludes HTML pages, the way it excludes pages" do
    assert_not_includes Post.articles, posts(:html_page)
    assert_kind_of HtmlPage, posts(:html_page)
  end

  # Slugs are the public URL space, shared by every kind — an HTML page must not be
  # able to shadow an existing post at the same root path.
  test "slug uniqueness is enforced across kinds" do
    assert_raises(ActiveRecord::RecordInvalid) do
      HtmlPage.create!(title: "Collision", slug: posts(:published).slug, raw_html: DOCUMENT)
    end
    assert_raises(ActiveRecord::RecordInvalid) do
      Post.create!(title: "Collision", slug: posts(:html_page).slug)
    end
  end
end
