# frozen_string_literal: true

class ListPostsTool < ActionTool::Base
  include PostToolSupport

  DEFAULT_LIMIT = 20
  MAX_LIMIT = 100

  tool_name "list_posts"
  description "List posts, pages and HTML pages with optional filters (status, kind, tag, title query). Paginated; returns metadata only, never bodies — call get_post for a body."
  annotations(
    title: "List Posts",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    optional(:status).filled(:string).description("Filter by status: 'draft', 'scheduled' (a draft with a future publish time), or 'published'.")
    optional(:kind).filled(:string).description("Filter by kind: 'article' (a blog post), 'page' (a standalone page like About) or 'html_page' (a whole hand-authored HTML document).")
    optional(:tag).filled(:string).description("Filter by tag slug.")
    optional(:query).filled(:string).description("Case-insensitive substring match on the title.")
    optional(:limit).filled(:integer).description("Max results (default: #{DEFAULT_LIMIT}, max: #{MAX_LIMIT}).")
    optional(:offset).filled(:integer).description("Results to skip for pagination (default: 0).")
  end

  def call(status: nil, kind: nil, tag: nil, query: nil, limit: DEFAULT_LIMIT, offset: 0)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    limit = limit.clamp(1, MAX_LIMIT)
    offset = [ offset, 0 ].max

    scope = Post.all
    scope = scope.merge(Post.articles) if kind == "article"
    # Exact types, not the STI hierarchy: kind: "page" means About, never the HTML pages
    # that inherit from it — they answer to their own kind and their own tools.
    scope = scope.where(type: "Page") if kind == "page"
    scope = scope.where(type: "HtmlPage") if kind == "html_page"

    now = Time.current
    case status
    when "published" then scope = scope.published
    when "scheduled" then scope = scope.draft.where("published_at > ?", now)
    when "draft"     then scope = scope.draft.where("published_at IS NULL OR published_at <= ?", now)
    end

    if tag.present?
      found_tag = Tag.find_by(slug: tag)
      return ToolErrors::TAG_NOT_FOUND unless found_tag
      scope = scope.joins(:taggings).where(taggings: { tag_id: found_tag.id })
    end

    if query.present?
      scope = scope.where("LOWER(title) LIKE ?", "%#{Post.sanitize_sql_like(query.downcase)}%")
    end

    scope = scope.ordered.includes(:tags)
    total_count = scope.count
    posts = scope.offset(offset).limit(limit)
    has_more = (offset + limit) < total_count

    {
      posts: posts.map { |post| summarize(post) },
      total_count: total_count,
      offset: offset,
      has_more: has_more,
      next_offset: (has_more ? offset + limit : nil)
    }
  end

  private
    def summarize(post)
      {
        id: post.id,
        slug: post.slug,
        title: post.title,
        kind: kind_of(post),
        status: status_of(post),
        published_at: post.published_at&.iso8601,
        excerpt: post.excerpt,
        tags: post.tags.map(&:slug)
      }
    end
end
