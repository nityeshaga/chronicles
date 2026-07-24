# frozen_string_literal: true

class CreateEmbedTool < ActionTool::Base
  tool_name "create_embed"
  description "Turn a YouTube or X/Twitter URL into the site's Ghost-parity kg-embed-card figure HTML. Splice the returned figure_html into a post body via update_post body_patches — never hand-write embed markup. Pure URL parsing, no fetching."
  annotations(
    title: "Create Embed",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:url).filled(:string).description("A YouTube or X/Twitter URL to embed.")
  end

  def call(url:)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    html = Embed.new(url).to_html
    unless html
      return { error: "That URL isn't a supported embed (YouTube or X/Twitter only). For an image use upload_image; for anything else, put a plain <a> link in the body." }
    end

    {
      figure_html: html,
      message: "Splice figure_html into a body with update_post body_patches (the 'old' anchor must appear exactly once), or include it in the body on create_post."
    }
  end
end
