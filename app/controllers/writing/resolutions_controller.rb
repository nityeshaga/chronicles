# Resolving a note is a noun with a lifecycle, not a verb on the note: create resolves,
# destroy reopens. The MCP's resolve_note tool calls the same model verb.
class Writing::ResolutionsController < ApplicationController
  before_action :set_note

  def create
    @note.resolve(params[:resolution])
    redirect_to writing_notes_path(path: @note.path), status: :see_other
  end

  def destroy
    @note.reopen
    redirect_to writing_notes_path(path: @note.path), status: :see_other
  end

  private
    def set_note
      @note = Current.user.notes.find(params[:note_id])
    end
end
