# frozen_string_literal: true

module ToolErrors
  AUTH_REQUIRED = { error: "Authentication required. Reconnect the nityesh-com MCP server with a valid API token." }.freeze
  POST_NOT_FOUND = { error: "Post not found. Use list_posts to find the right id or slug." }.freeze
  TAG_NOT_FOUND = { error: "Tag not found. Use list_tags to see the available tag slugs." }.freeze
  INVALID_KIND = { error: "kind must be 'article' or 'page'." }.freeze
  HTML_PAGE_KIND = { error: "kind 'html_page' isn't set here. A whole-document HTML page is created with create_html_page and edited with update_html_page." }.freeze
  NOT_AN_HTML_PAGE = { error: "That's a regular post or page, not an HTML page. Use update_post to edit it." }.freeze
  IS_AN_HTML_PAGE = { error: "That's an HTML page: its body is a whole stored HTML document, not Action Text. Use update_html_page to edit it." }.freeze
end
