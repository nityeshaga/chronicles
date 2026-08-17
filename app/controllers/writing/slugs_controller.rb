# Is this URL still free? Asked from the editor as the writer types, answered as a
# turbo-frame the field swaps in place — so what counts as "free" stays on the server,
# in Slug, and never has to be re-implemented (or drift) in JavaScript.
class Writing::SlugsController < Writing::BaseController
  layout false

  def show
    @state = Slug.new(params[:slug], except: params[:except]).state
  end
end
