require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative "../lib/mcp_session_store"
require_relative "../lib/streamable_http_mcp_transport"

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks mcp_session_store.rb streamable_http_mcp_transport.rb])

    # The agent-native MCP server: a single /mcp endpoint (Streamable HTTP, spec
    # 2025-11-25) served as Rack middleware. Bearer auth resolves via ApiToken; the
    # DB-backed session store lets sessions survive restarts and deploys.
    config.middleware.use StreamableHttpMcpTransport,
      FastMcp::Server.new(name: "nityesh-com", version: "1.0.0"),
      localhost_only: false,
      allowed_origins: [ /.*/ ],
      session_store: McpSessionStore.new

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # The Ghost blog this replaced ran on Asia/Kolkata; match it so published_at
    # renders and datetime-local scheduling parse in the author's own wall clock.
    # Active Record keeps storing UTC (default default_timezone).
    config.time_zone = "Asia/Kolkata"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
