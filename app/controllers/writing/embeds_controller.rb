class Writing::EmbedsController < Writing::BaseController
  # Paste a URL → get provider HTML back for the editor to insert as an Action Text
  # content attachment. The client invents no embed markup; the Embed noun owns it.
  def create
    if html = Embed.new(params[:url]).to_html
      render html: html.html_safe
    else
      render plain: "Unsupported embed URL", status: :unprocessable_entity
    end
  end
end
