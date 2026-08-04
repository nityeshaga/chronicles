# frozen_string_literal: true

# Server-level instructions the MCP host reads before calling any tool: the blog's
# voice, Ghost-parity markup rules, and the draft-first workflow. A placeholder until
# stages 2-4 land the tools it describes. (fast-mcp 1.6 does not yet surface server
# instructions in the initialize handshake; kept here as the single source for when it
# does, or for a manual capabilities merge.)
#
# A proc, not a String: it reads the Setting row for the host, and this initializer
# runs before the DB is guaranteed to exist (migrations, asset precompile), so the
# value is resolved lazily at call time.
MCP_SERVER_INSTRUCTIONS = -> do
  <<~INSTRUCTIONS
  Agent-native authoring for #{Setting.current.production_host}, a personal blog.

  Workflow: draft first. create_post always makes a draft — write and revise it with
  update_post, then take it live with publish_post (pass `at:` a future time to schedule;
  a scheduled post is just a draft with a future published_at).

  Bodies are HTML using Ghost-parity kg-* card markup. Never hand-write image or embed
  markup: get images from upload_image (or the POST /writing/uploads endpoint) and embeds
  from create_embed, then paste the figure_html they return. A cover image is the post's
  feature_image (a plain URL); an in-body image is a figure spliced into the body.

  Edit long posts with update_post body_patches ({old,new} find/replace) instead of
  resending the whole body — each `old` anchor must match exactly once, so include enough
  surrounding context. title and excerpt are single-line (the excerpt is the standfirst).

  Changing the slug of a published post 404s its old URL — there are no redirects. Use
  list_posts / list_tags to resolve the right slug before editing.

  HTML pages are the third kind: one complete hand-authored document (<html>…</html>, its
  own head, styles, scripts) served verbatim at a root slug with no blog chrome — for a
  landing page or a one-off whose design IS the content. Anything that reads as writing is
  a post. Author them with create_html_page / update_html_page (which takes html_patches
  the same way update_post takes body_patches); update_post refuses them and there is no
  `kind: html_page`. get_post, list_posts, publish_post, unpublish_post and delete_post
  treat them like any other record — get_post's body window is the document itself.

  The contract is a self-contained document: absolute URLs for every asset (upload_image
  returns them), no relative paths, no tags. Both tools screen it on the way in — a
  fragment or a head with no <title> is rejected outright; a missing
  <meta name="description"> and relative references come back as warnings, not blocks; and
  <link rel="canonical" href="https://#{Setting.current.production_host}/<slug>/"> is
  injected before </head> unless the document already carries a canonical (one aimed at
  another site is left alone and reported, and a rename keeps a self-referential one
  correct). Documents saved through the writing UI are never screened or injected — this
  MCP path is the only one that touches the bytes.
  INSTRUCTIONS
end

# Tool annotations note: when write tools land, mark ALL of them destructive_hint: true,
# even creates. The MCP spec considers creates non-destructive, but Claude's MCP Directory
# submission guide requires destructiveHint: true for any tool that writes/modifies data.
# See: https://support.claude.com/en/articles/12922490-remote-mcp-server-submission-guide

# Register MCP tools after Rails has fully loaded.
Rails.application.config.after_initialize do
  mcp_middleware = Rails.application.middleware.find { |m| m.klass == StreamableHttpMcpTransport }

  if mcp_middleware
    server = mcp_middleware.args.first

    # Read tools (stage 2)
    server.register_tool(ListPostsTool)
    server.register_tool(GetPostTool)
    server.register_tool(ListTagsTool)

    # Write tools (stage 3)
    server.register_tool(CreatePostTool)
    server.register_tool(UpdatePostTool)
    server.register_tool(PublishPostTool)
    server.register_tool(UnpublishPostTool)
    server.register_tool(DeletePostTool)
    server.register_tool(UpdateTagTool)

    # Whole-document HTML pages: their own tools because they bypass Action Text entirely.
    server.register_tool(CreateHtmlPageTool)
    server.register_tool(UpdateHtmlPageTool)

    # Image + embed tools (stage 4)
    server.register_tool(UploadImageTool)
    server.register_tool(CreateEmbedTool)

    Rails.logger.info "MCP Server: Registered #{server.tools.keys.size} tools: #{server.tools.keys.join(', ')}"
  end
end
