# frozen_string_literal: true

class CreatePostTool < ActionTool::Base
  include PostToolSupport

  tool_name "create_post"
  description "Create a new post or page. ALWAYS creates a draft — publishing is a separate step (call publish_post afterward). Title and excerpt are squished to one line; slug auto-generates from the title unless you pass one. Returns the id, slug, and edit URL."
  annotations(
    title: "Create Post",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:title).filled(:string).description("The post title.")
    optional(:kind).filled(:string).description("'article' (a blog post, the default) or 'page' (a standalone page like About). A whole-document HTML page is not a kind here — it has its own tool, create_html_page.")
    optional(:body).filled(:string).description("Body HTML. For images/embeds use Ghost-parity kg-* card markup — call upload_image/create_embed rather than hand-writing it. Markup that must be served exactly as written (a CSS grid, a chart that draws itself) is an HTML card: call create_html_card and paste the attachment element it returns, because a <style> or <script> written into the body itself is sanitized away. A real <table> needs no card — tables are ordinary prose here and render natively in Gmail.")
    optional(:excerpt).filled(:string).description("The standfirst shown under the title, on the home feed, and in social cards.")
    optional(:slug).filled(:string).description("Explicit URL slug. Omit to auto-generate from the title.")
    optional(:tags).array(:string).description("Tag NAMES. Existing tags are reused; unknown names are created (auto-slugged).")
    optional(:feature_image).filled(:string).description("Cover image URL.")
    optional(:feature_image_caption).filled(:string).description("Caption for the cover image.")
    optional(:meta_title).filled(:string).description("SEO title override.")
    optional(:meta_description).filled(:string).description("SEO meta description override.")
  end

  def call(title:, kind: "article", body: nil, excerpt: nil, slug: nil, tags: nil, feature_image: nil, feature_image_caption: nil, meta_title: nil, meta_description: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user
    # Named separately from the generic kind error: an agent reaching for html_page has the
    # right intent and the wrong door, so send it to the door rather than to the kind list.
    return ToolErrors::HTML_PAGE_KIND if kind == "html_page"
    return ToolErrors::INVALID_KIND unless %w[ article page ].include?(kind)

    post = (kind == "page" ? Page : Post).new(
      title: title,
      excerpt: excerpt,
      slug: slug,
      feature_image: feature_image,
      feature_image_caption: feature_image_caption,
      meta_title: meta_title,
      meta_description: meta_description
    )
    post.body = body if body.present?
    post.tags = find_or_create_tags(tags) if tags.present?

    if post.save
      {
        id: post.id,
        slug: post.slug,
        status: status_of(post),
        edit_url: edit_url(post),
        message: "Draft created. Revise it with update_post, then take it live with publish_post."
      }
    else
      { error: post.errors.full_messages.join(", ") }
    end
  end
end
