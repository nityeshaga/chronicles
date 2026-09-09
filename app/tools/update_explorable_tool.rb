# frozen_string_literal: true

class UpdateExplorableTool < ActionTool::Base
  include PostToolSupport
  include HtmlIngestGate
  include ExplorableToolSupport

  tool_name "update_explorable"
  description "Update an explorable: add or replace files (by path — an existing path is overwritten, a new one is added, index.html replaces the front document), remove files by path, or change the title or slug. Only the files you send change; the rest of the bundle stays as it is, so a one-deck fix is a one-file call. A changed index.html is re-screened (<title> required, canonical kept pointing at /slug/) and the whole bundle's relative references are re-checked. Changing a published explorable's slug moves every file's URL and 404s the old ones — the response warns you."
  annotations(
    title: "Update Explorable",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:id_or_slug).filled.description("The explorable's numeric id or its slug string.")
    optional(:title).filled(:string).description("New title (listings only).")
    optional(:slug).filled(:string).description("New slug. Changing it on a published explorable 404s every old URL.")
    optional(:files).value(:array, min_size?: 1).description("Files to add or replace. #{FILE_ARGUMENT}")
    optional(:remove_paths).value(:array, min_size?: 1).description("Paths to delete from the bundle. index.html can't be removed — replace it instead.")
  end

  def call(id_or_slug:, title: nil, slug: nil, files: nil, remove_paths: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    explorable = resolve_post(id_or_slug)
    return ToolErrors::POST_NOT_FOUND unless explorable
    return ToolErrors::NOT_AN_EXPLORABLE unless explorable.is_a?(Explorable)

    files, error = unpack_files(files || [])
    return error if error

    removals = Array(remove_paths).map { |path| Explorable::Asset.normalize_path(path) }
    return { error: "index.html can't be removed — it's the explorable's front door. Send a replacement in files instead." } if removals.include?(Explorable::INDEX)

    slug_was = explorable.slug
    was_published = explorable.published?
    changed = []

    if title;         explorable.title = title; changed << "title"; end
    if slug.present?; explorable.slug = slug;   changed << "slug";  end

    index = files.find { |file| file[:path] == Explorable::INDEX }
    explorable.raw_html = index[:content] if index
    return { error: explorable.errors.full_messages.join(", ") } unless explorable.valid?

    # A slug rename is a document change too: the canonical in index.html names the old URL.
    warnings = []
    if index || explorable.slug != slug_was
      screened = screen_html_document(explorable.raw_html, canonical_url: public_url(explorable), references: false)
      return screened if screened[:error]

      explorable.raw_html = screened[:html]
      index[:content] = screened[:html] if index
      warnings = screened[:warnings]
    end

    doomed = explorable.assets.where(path: removals)
    unknown = removals - doomed.pluck(:path)
    return { error: "Not in the bundle, so nothing was changed: #{unknown.join(", ")}. Call get_post to see the files it has." } if unknown.any?

    begin
      explorable.transaction do
        explorable.save!
        explorable.write_files(files)
        doomed.destroy_all
      end
    rescue ActiveRecord::RecordInvalid => invalid
      return { error: invalid.record.errors.full_messages.map { |message| "#{invalid.record.try(:path)}: #{message}".delete_prefix(": ") }.join(", ") }
    end

    changed << "files" if files.any?
    changed << "removed" if removals.any?
    if was_published && explorable.slug != slug_was
      warnings << "Slug changed on a published explorable: every URL under /#{slug_was}/ now 404s — there are no redirects. Update any links pointing there."
    end
    warnings << missing_reference_warning(explorable)

    describe(explorable.reload, warnings: warnings.compact).merge(changed: changed)
  end
end
