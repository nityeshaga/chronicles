# frozen_string_literal: true

class ResolveNoteTool < ActionTool::Base
  tool_name "resolve_note"
  description "Mark a red-pen note done, with one line on what changed (it shows under the note on the page). Only the author can reopen a note, from the page."
  annotations(
    title: "Resolve Note",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:id).filled(:integer).description("The note's id, from list_notes.")
    required(:resolution).filled(:string).description("One line on what changed, e.g. 'Trimmed the excerpt to two sentences via update_post'.")
  end

  def call(id:, resolution:)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    note = Note.find_by(id: id)
    return { error: "No note with id #{id}. Call list_notes for the current ids." } unless note

    note.resolve(resolution)
    { id: note.id, path: note.path, resolved_at: note.resolved_at.iso8601, resolution: note.resolution }
  end
end
