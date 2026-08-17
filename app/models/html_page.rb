# A page whose body is a complete, hand-authored HTML document — its own <head>,
# fonts, styles, scripts — served verbatim at a root slug with no blog chrome.
# Everything else (slug generation and uniqueness, publish/schedule verbs, draft
# 404s, sitemap-pages listing) is inherited from Page, which is the whole reason
# this kind is one subclass and not a second content system.
class HtmlPage < Page
  validates :raw_html, presence: true
  validate :looks_like_a_full_document

  def dashboard_bucket = "html_page"

  private
    # A pasted fragment would publish as a broken white page — no doctype, no head,
    # none of the styling the document is supposed to carry — and nothing downstream
    # would notice, because we render the bytes untouched. Catch it at save, where
    # the author (or the agent) is still holding the source.
    def looks_like_a_full_document
      return if raw_html.blank?

      unless raw_html.match?(/<html[\s>]/i) && raw_html.match?(%r{</html>}i)
        errors.add(:raw_html, "must be a complete HTML document (<html>…</html>)")
      end
    end
end
