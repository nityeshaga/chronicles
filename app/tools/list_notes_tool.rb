# frozen_string_literal: true

class ListNotesTool < ActionTool::Base
  tool_name "list_notes"
  description "The author's red-pen notes: feedback pinned to elements of live pages ('cut this excerpt', 'swap this image'). Open notes are work to do — each carries the page path, a CSS selector for the element and a snippet of its text. Do the work (update_post, update_html_page, or a code change), then resolve_note with one line on what changed."
  annotations(
    title: "List Notes",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    optional(:status).filled(:string).description("'open' (default), 'resolved' or 'all'.")
    optional(:path).filled(:string).description("Only notes on this site path, e.g. '/about/'.")
  end

  def call(status: "open", path: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    scope = case status
    when "open"     then Redpen::Note.open
    when "resolved" then Redpen::Note.resolved
    when "all"      then Redpen::Note.all
    else return { error: "status must be 'open', 'resolved' or 'all'." }
    end
    scope = scope.on(path) if path.present?

    { notes: scope.ordered.map { |note| serialize(note) } }
  end

  private
    def serialize(note)
      {
        id: note.id,
        path: note.path,
        url: "https://#{Setting.current.production_host}#{note.path}",
        selector: note.selector,
        snippet: note.snippet,
        body: note.body,
        created_at: note.created_at.iso8601,
        resolved_at: note.resolved_at&.iso8601,
        resolution: note.resolution
      }.compact
    end
end
