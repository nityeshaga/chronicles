# frozen_string_literal: true

class UpdateTagTool < ActionTool::Base
  tool_name "update_tag"
  description "Update a tag's name, description, or slug, identified by its current slug. Renaming the slug is allowed but 404s the old public tag URL (no redirects) — the response warns you."
  annotations(
    title: "Update Tag",
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true,
    open_world_hint: false
  )

  arguments do
    required(:slug).filled(:string).description("The current slug identifying the tag.")
    optional(:name).filled(:string).description("New display name.")
    optional(:description).filled(:string).description("New description.")
    optional(:new_slug).filled(:string).description("New slug. Changing it 404s the old /tag/<slug>/ URL.")
  end

  def call(slug:, name: nil, description: nil, new_slug: nil)
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    tag = Tag.find_by(slug: slug)
    return ToolErrors::TAG_NOT_FOUND unless tag

    slug_was = tag.slug
    tag.name = name if name.present?
    tag.description = description unless description.nil?
    tag.slug = new_slug if new_slug.present?

    if tag.save
      result = { id: tag.id, name: tag.name, slug: tag.slug, description: tag.description }
      if tag.slug != slug_was
        result[:warning] = "Tag slug changed: the old URL (/tag/#{slug_was}/) now 404s — there are no redirects."
      end
      result
    else
      { error: tag.errors.full_messages.join(", ") }
    end
  end
end
