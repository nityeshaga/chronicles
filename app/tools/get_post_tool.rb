# frozen_string_literal: true

class GetPostTool < ActionTool::Base
  BODY_CHARACTER_LIMIT = 20_000

  tool_name "get_post"
  description "Get a single post or page with all authoring fields and its body HTML, windowed by body_offset/body_limit so a long essay can't blow the context."
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

    key = id_or_slug.to_s
    post = key.match?(/\A\d+\z/) ? Post.find_by(id: key) : Post.find_by(slug: key)
    return ToolErrors::POST_NOT_FOUND unless post

    # Raw stored fragment, not post.body.to_s (that renders the layout wrapper, which re-persists and nests on the next edit).
    body_html = post.body&.body&.to_html.to_s
    body_offset = [ body_offset, 0 ].max
    body_slice = body_html[body_offset, body_limit] || ""

    {
      id: post.id,
      slug: post.slug,
      title: post.title,
      kind: post.is_a?(Page) ? "page" : "article",
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
      body: body_slice,
      body_offset: body_offset,
      body_total_length: body_html.length,
      body_truncated: (body_offset + body_slice.length) < body_html.length
    }
  end

  private
    def status_of(post)
      if post.published?
        "published"
      elsif post.scheduled?
        "scheduled"
      else
        "draft"
      end
    end

    def public_url(post)
      Rails.application.routes.url_helpers.post_url(
        post,
        host: Setting.current.production_host,
        protocol: "https",
        trailing_slash: true
      )
    end
end
