# frozen_string_literal: true

class UpdatePostTool < ActionTool::Base
  include PostToolSupport

  tool_name "update_post"
  description "Update a post or page. Pass body for a full replacement OR body_patches for surgical find/replace edits (mutually exclusive). tags REPLACES the full tag set when given. Changing a published post's slug is allowed but 404s the old URL (no redirects) — the response warns you."
  annotations(
    title: "Update Post",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: false,
    open_world_hint: false
  )

  arguments do
    required(:id_or_slug).filled.description("The post's numeric id or its slug string.")
    optional(:title).filled(:string).description("New title.")
    optional(:kind).filled(:string).description("Change the kind: 'article' or 'page'. HTML pages are neither — they are edited with update_html_page.")
    optional(:body).filled(:string).description("Full replacement body HTML. Mutually exclusive with body_patches.")
    optional(:body_patches).value(:array, min_size?: 1).description('Array of {"old","new"} pairs for surgical edits. Each "old" must appear exactly once in the current body. Mutually exclusive with body.')
    optional(:excerpt).filled(:string).description("New excerpt / standfirst.")
    optional(:slug).filled(:string).description("New slug. Changing it on a published post 404s the old URL.")
    optional(:tags).array(:string).description("Tag NAMES. REPLACES the post's entire tag set. Existing tags are reused; unknown names are created.")
    optional(:feature_image).filled(:string).description("New cover image URL.")
    optional(:feature_image_caption).filled(:string).description("New cover image caption.")
    optional(:meta_title).filled(:string).description("New SEO title.")
    optional(:meta_description).filled(:string).description("New SEO meta description.")
  end

  def call(id_or_slug:, title: nil, kind: nil, body: nil, body_patches: nil, excerpt: nil, slug: nil, tags: nil, feature_image: nil, feature_image_caption: nil, meta_title: nil, meta_description: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    post = resolve_post(id_or_slug)
    return ToolErrors::POST_NOT_FOUND unless post
    # An HtmlPage has no Action Text body, so every field this tool writes would either
    # no-op or quietly grow a body nothing renders. Refuse at the door.
    return ToolErrors::IS_AN_HTML_PAGE if post.is_a?(HtmlPage)

    return { error: "body and body_patches are mutually exclusive. Pass body for a full replacement or body_patches for surgical edits, not both." } if body.present? && body_patches.present?
    return ToolErrors::HTML_PAGE_KIND if kind == "html_page"
    return ToolErrors::INVALID_KIND if kind.present? && !%w[ article page ].include?(kind)

    slug_was = post.slug
    was_published = post.published?
    kind_changed = false
    changed = []

    if kind.present?
      new_type = kind == "page" ? "Page" : "Post"
      if post.type != new_type
        post.type = new_type
        kind_changed = true
        changed << "kind"
      end
    end

    if title;                          post.title = title;                                 changed << "title"; end
    unless excerpt.nil?;               post.excerpt = excerpt;                             changed << "excerpt"; end
    if slug.present?;                  post.slug = slug;                                   changed << "slug"; end
    unless feature_image.nil?;         post.feature_image = feature_image;                 changed << "feature_image"; end
    unless feature_image_caption.nil?; post.feature_image_caption = feature_image_caption; changed << "feature_image_caption"; end
    unless meta_title.nil?;            post.meta_title = meta_title;                       changed << "meta_title"; end
    unless meta_description.nil?;      post.meta_description = meta_description;            changed << "meta_description"; end

    unless tags.nil?
      post.tags = find_or_create_tags(tags)
      changed << "tags"
    end

    if body.present?
      post.body = body
      changed << "body"
    elsif body_patches.present?
      error = apply_body_patches(post, body_patches)
      return error if error
      changed << "body"
    end

    if post.save
      post = Post.find(post.id) if kind_changed
      result = {
        changed: changed,
        slug: post.slug,
        status: status_of(post),
        edit_url: edit_url(post),
        url: (public_url(post) if post.published?)
      }
      result[:body_patches_applied] = body_patches.size if body_patches.present?
      if was_published && post.slug != slug_was
        result[:warning] = "Slug changed on a published post: the old URL (/#{slug_was}/) now 404s — there are no redirects. Update any links pointing to it."
      end
      result
    else
      { error: post.errors.full_messages.join(", ") }
    end
  end

  private
    def apply_body_patches(post, patches)
      text = post.body&.body&.to_html.to_s

      patches.each_with_index do |patch, i|
        old_text = patch["old"] || patch[:old]
        new_text = patch["new"] || patch[:new]
        return { error: "Patch #{i} is missing an 'old' or 'new' value." } if old_text.nil? || new_text.nil?

        first = text.index(old_text)
        if first.nil?
          return { error: "Patch #{i}: its 'old' text was not found in the current body. Call get_post to re-read the body, then match it exactly (whitespace and HTML tags included)." }
        elsif text.index(old_text, first + 1)
          return { error: "Patch #{i}: its 'old' text appears more than once in the body. Include more surrounding context so it matches exactly once." }
        end

        # Block form: a string replacement would interpret \0, \', \\ … in new_text.
        text = text.sub(old_text) { new_text }
      end

      post.body = text
      nil
    end
end
