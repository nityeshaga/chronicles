# frozen_string_literal: true

class UpdateHtmlPageTool < ActionTool::Base
  include PostToolSupport
  include HtmlIngestGate

  tool_name "update_html_page"
  description "Update an HTML page. Pass html for a full document replacement OR html_patches for surgical find/replace edits (mutually exclusive) — a 50KB document doesn't want resending for a one-line change. Any change to the document, or to the slug, re-runs the ingest gate: <title> stays required, a missing meta description and relative asset paths are reported, and the canonical is kept pointing at this page's URL. Changing a published page's slug is allowed but 404s the old URL (no redirects) — the response warns you. Regular posts and pages are edited with update_post."
  annotations(
    title: "Update HTML Page",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:id_or_slug).filled.description("The page's numeric id or its slug string.")
    optional(:title).filled(:string).description("New title (listings only — readers see the document's own <title>).")
    optional(:html).filled(:string).description("Full replacement document. Mutually exclusive with html_patches.")
    optional(:html_patches).value(:array, min_size?: 1).description('Array of {"old","new"} pairs for surgical edits. Each "old" must appear exactly once in the current document. Mutually exclusive with html.')
    optional(:slug).filled(:string).description("New slug. Changing it on a published page 404s the old URL.")
  end

  def call(id_or_slug:, title: nil, html: nil, html_patches: nil, slug: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    page = resolve_post(id_or_slug)
    return ToolErrors::POST_NOT_FOUND unless page
    return ToolErrors::NOT_AN_HTML_PAGE unless page.is_a?(HtmlPage)

    return { error: "html and html_patches are mutually exclusive. Pass html for a full replacement or html_patches for surgical edits, not both." } if html.present? && html_patches.present?

    slug_was = page.slug
    was_published = page.published?
    changed = []

    if title;          page.title = title; changed << "title"; end
    if slug.present?;  page.slug = slug;   changed << "slug"; end

    if html.present?
      page.raw_html = html
      changed << "html"
    elsif html_patches.present?
      error = apply_html_patches(page, html_patches)
      return error if error
      changed << "html"
    end

    return { error: page.errors.full_messages.join(", ") } unless page.valid?

    # A slug rename is a document change too: the canonical the gate wrote names the old
    # URL, and left alone it would point every crawler at a path that now 404s.
    warnings = []
    if changed.include?("html") || page.slug != slug_was
      screened = screen_html_document(page.raw_html, canonical_url: public_url(page))
      return screened if screened[:error]

      page.raw_html = screened[:html]
      warnings = screened[:warnings]
    end

    if page.save
      result = {
        changed: changed,
        slug: page.slug,
        status: status_of(page),
        edit_url: edit_url(page),
        url: (public_url(page) if page.published?)
      }
      result[:html_patches_applied] = html_patches.size if html_patches.present?
      if was_published && page.slug != slug_was
        warnings << "Slug changed on a published page: the old URL (/#{slug_was}/) now 404s — there are no redirects. Update any links pointing to it."
      end
      result[:warnings] = warnings if warnings.any?
      result
    else
      { error: page.errors.full_messages.join(", ") }
    end
  end

  private
    def apply_html_patches(page, patches)
      text = page.raw_html.to_s

      patches.each_with_index do |patch, i|
        old_text = patch["old"] || patch[:old]
        new_text = patch["new"] || patch[:new]
        return { error: "Patch #{i} is missing an 'old' or 'new' value." } if old_text.nil? || new_text.nil?

        first = text.index(old_text)
        if first.nil?
          return { error: "Patch #{i}: its 'old' text was not found in the current document. Call get_post to re-read it, then match it exactly (whitespace and HTML tags included)." }
        elsif text.index(old_text, first + 1)
          return { error: "Patch #{i}: its 'old' text appears more than once in the document. Include more surrounding context so it matches exactly once." }
        end

        # Block form: a string replacement would interpret \0, \', \\ … in new_text.
        text = text.sub(old_text) { new_text }
      end

      page.raw_html = text
      nil
    end
end
