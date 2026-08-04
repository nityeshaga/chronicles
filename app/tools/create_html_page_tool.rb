# frozen_string_literal: true

class CreateHtmlPageTool < ActionTool::Base
  include PostToolSupport
  include HtmlIngestGate

  tool_name "create_html_page"
  description "Create an HTML page: one complete hand-authored HTML document (<html>…</html> with its own head, styles and scripts) served verbatim at a root slug with no blog chrome. For landing pages and one-offs whose design is the point — anything that reads as writing is a create_post. The document must be self-contained (absolute URLs for every asset; upload_image returns them). It is screened on the way in: a fragment or a head with no <title> is rejected, a missing meta description or a relative asset path is reported back, and a canonical link for this page's URL is injected before </head> unless the document already carries one. ALWAYS creates a draft — publishing is a separate step (call publish_post afterward)."
  annotations(
    title: "Create HTML Page",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:title).filled(:string).description("The page title. Identity for listings and the writing dashboard only — readers see the document's own <title>.")
    required(:html).filled(:string).description("The complete HTML document, served byte-for-byte. Must include <html>…</html> and a <title> in its head.")
    optional(:slug).filled(:string).description("Explicit URL slug — the page is served at /slug/. Omit to auto-generate from the title.")
  end

  def call(title:, html:, slug: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    page = HtmlPage.new(title: title, slug: slug, raw_html: html)

    # Validate before screening, for two reasons: the whole-document check belongs to the
    # model (so a fragment is refused in the same words the writing UI shows), and it's the
    # validation pass that settles an auto-generated slug — which is what the canonical the
    # gate injects is built from.
    return { error: page.errors.full_messages.join(", ") } unless page.valid?

    screened = screen_html_document(html, canonical_url: public_url(page))
    return screened if screened[:error]

    page.raw_html = screened[:html]

    if page.save
      {
        id: page.id,
        slug: page.slug,
        status: status_of(page),
        edit_url: edit_url(page),
        warnings: screened[:warnings].presence,
        message: "Draft created. Revise it with update_html_page, then take it live with publish_post."
      }.compact
    else
      { error: page.errors.full_messages.join(", ") }
    end
  end
end
