# frozen_string_literal: true

class CreateExplorableTool < ActionTool::Base
  include PostToolSupport
  include HtmlIngestGate
  include ExplorableToolSupport

  tool_name "create_explorable"
  description "Create an explorable: a whole directory of hand-authored static files — an index.html plus any decks, stylesheets, scripts and images — served as written under one root slug (/slug/ is index.html, /slug/decks/x.html is decks/x.html). Relative links inside the bundle resolve exactly as on disk; nothing is rewritten. Use it for explorable explanations, interactive tutorials, slide decks — anything that is several files. A single self-contained document is a create_html_page; prose is a create_post. index.html is screened like an HTML page (a <title> is required, a canonical for /slug/ is injected) and every relative src/href across the bundle's HTML is checked against the bundle — unresolved ones come back as a warning. ALWAYS creates a draft; take it live with publish_post. A signed-in writer can preview the draft at its real URL."
  annotations(
    title: "Create Explorable",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:title).filled(:string).description("The explorable's title. Identity for listings and the writing dashboard only — readers see index.html's own <title>.")
    required(:files).value(:array, min_size?: 1).description("The bundle. Must include index.html at the root. #{FILE_ARGUMENT}")
    optional(:slug).filled(:string).description("Explicit URL slug — the explorable is served at /slug/. Omit to auto-generate from the title.")
  end

  def call(title:, files:, slug: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    files, error = unpack_files(files)
    return error if error

    index = files.find { |file| file[:path] == Explorable::INDEX }
    return { error: "The bundle has no index.html at its root. That file is the explorable's front door — /slug/ serves it — so add it and resend." } unless index

    explorable = Explorable.new(title: title, slug: slug, raw_html: index[:content])
    # Validate first: the whole-document check belongs to the model, and the validation pass
    # settles an auto-generated slug — which the injected canonical is built from.
    return { error: explorable.errors.full_messages.join(", ") } unless explorable.valid?

    screened = screen_html_document(index[:content], canonical_url: public_url(explorable), references: false)
    return screened if screened[:error]

    index[:content] = screened[:html]

    begin
      explorable.transaction do
        explorable.save!
        explorable.write_files(files)
      end
    rescue ActiveRecord::RecordInvalid => invalid
      return { error: invalid.record.errors.full_messages.map { |message| "#{invalid.record.try(:path)}: #{message}".delete_prefix(": ") }.join(", ") }
    end

    warnings = screened[:warnings] + [ missing_reference_warning(explorable) ].compact
    describe(explorable, warnings: warnings).merge(message: "Draft created with #{pluralize_files(files.size)}. Revise with update_explorable, then take it live with publish_post.")
  end

  private
    def pluralize_files(count) = "#{count} #{"file".pluralize(count)}"
end
