# The author's notes on one page of the site. Every write redirects back to the index,
# which is the whole rail: pins, popovers, the composer. One renderer, so a note looks
# the same whether it arrived with the page or a second ago.
class Writing::NotesController < ApplicationController
  # The index answers a <turbo-frame> in the public layout. That layout would render
  # another rail inside this one, so no layout at all.
  layout false

  def index
    @path = params[:path].to_s
    @notes = Current.user.notes.on(@path).ordered
  end

  def create
    note = Current.user.notes.create(note_params)
    redirect_to writing_notes_path(path: note.path), status: :see_other
  end

  def destroy
    note = Current.user.notes.find(params[:id])
    note.destroy
    redirect_to writing_notes_path(path: note.path), status: :see_other
  end

  private
    def note_params
      params.expect(note: %i[ path selector snippet body ])
    end
end
