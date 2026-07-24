# frozen_string_literal: true

class ListTagsTool < ActionTool::Base
  tool_name "list_tags"
  description "List every tag with its slug, description, and how many posts carry it (published and total)."
  annotations(
    title: "List Tags",
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false
  )

  def call
    user = Thread.current[:mcp_current_user]
    return ToolErrors::AUTH_REQUIRED unless user

    {
      tags: Tag.order(:name).map do |tag|
        {
          id: tag.id,
          name: tag.name,
          slug: tag.slug,
          description: tag.description,
          published_post_count: tag.posts.published.count,
          total_post_count: tag.posts.count
        }
      end
    }
  end
end
