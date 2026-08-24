# frozen_string_literal: true

class GetPostTool < ActionTool::Base
  include PostToolSupport

  BODY_CHARACTER_LIMIT = 20_000

  tool_name "get_post"
  description "Get a single post, page or HTML page with all authoring fields and its body HTML, windowed by body_offset/body_limit so a long essay can't blow the context. For an HTML page the window reads the stored document itself."
  annotations(
    title: "Get Post",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:id_or_slug).filled.description("The post's numeric id or its slug string.")
    optional(:body_offset).filled(:integer).description("Character offset to start reading the body from (default: 0).")
    optional(:body_limit).filled(:integer).description("Max characters of body HTML to return (default: #{BODY_CHARACTER_LIMIT}).")
  end

  def call(id_or_slug:, body_offset: 0, body_limit: BODY_CHARACTER_LIMIT)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    post = resolve_post(id_or_slug)
    return ToolErrors::POST_NOT_FOUND unless post

    # Raw stored fragment, not post.body.to_s (that renders the layout wrapper, which re-persists and nests on the next edit).
    # An HTML page has no Action Text record at all — it IS its document, so the window reads that.
    body_html = post.is_a?(HtmlPage) ? post.raw_html.to_s : post.body&.body&.to_html.to_s
    body_offset = [ body_offset, 0 ].max
    body_slice = body_html[body_offset, body_limit] || ""

    {
      id: post.id,
      slug: post.slug,
      title: post.title,
      kind: kind_of(post),
      status: status_of(post),
      published_at: post.published_at&.iso8601,
      excerpt: post.excerpt,
      feature_image: post.feature_image,
      feature_image_caption: post.feature_image_caption,
      meta_title: post.meta_title,
      meta_description: post.meta_description,
      tags: post.tags.map { |tag| { name: tag.name, slug: tag.slug } },
      created_at: post.created_at&.iso8601,
      updated_at: post.updated_at&.iso8601,
      url: (public_url(post) if post.published?),
      # The body carries an sgid, which is nothing an agent can hand to update_html_card.
      # Without this, a card written a session ago can only be replaced, never revised.
      html_card_ids: post.try(:body)&.body&.attachables.to_a.grep(HtmlCard).map(&:id).presence,
      body: body_slice,
      body_offset: body_offset,
      body_total_length: body_html.length,
      body_truncated: (body_offset + body_slice.length) < body_html.length
    }
  end
end
