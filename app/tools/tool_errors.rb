# frozen_string_literal: true

module ToolErrors
  AUTH_REQUIRED = { error: "Authentication required. Reconnect the nityesh-com MCP server with a valid API token." }.freeze
  POST_NOT_FOUND = { error: "Post not found. Use list_posts to find the right id or slug." }.freeze
  TAG_NOT_FOUND = { error: "Tag not found. Use list_tags to see the available tag slugs." }.freeze
  INVALID_KIND = { error: "kind must be 'article' or 'page'." }.freeze
end
