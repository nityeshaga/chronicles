# frozen_string_literal: true

require "fast_mcp"
require "json"
require "concurrent"

# Streamable HTTP MCP Transport implementing MCP spec 2025-11-25
# Single endpoint supporting POST, GET, DELETE methods with session management
class StreamableHttpMcpTransport
  MCP_PATH = "/mcp"
  PROTOCOL_VERSION = "2025-11-25"
  DEFAULT_ALLOWED_ORIGINS = [ "localhost", "127.0.0.1", "[::1]" ].freeze
  DEFAULT_ALLOWED_IPS = [ "127.0.0.1", "::1", "::ffff:127.0.0.1" ].freeze

  SSE_HEADERS = {
    "Content-Type" => "text/event-stream",
    "Cache-Control" => "no-cache, no-store, must-revalidate",
    "Connection" => "keep-alive",
    "X-Accel-Buffering" => "no",
    "Access-Control-Allow-Origin" => "*",
    "Access-Control-Allow-Methods" => "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers" => "Content-Type, Authorization, Accept, MCP-Session-Id, MCP-Protocol-Version"
  }.freeze

  attr_reader :app, :server, :logger, :session_store

  def initialize(app, server, options = {})
    @app = app
    @server = server
    @logger = options[:logger] || Rails.logger
    @localhost_only = options.fetch(:localhost_only, true)
    @allowed_origins = options[:allowed_origins] || DEFAULT_ALLOWED_ORIGINS
    @allowed_ips = options[:allowed_ips] || DEFAULT_ALLOWED_IPS
    @session_store = options[:session_store] || InMemorySessionStore.new
    @sse_clients = Concurrent::Hash.new
    @sse_clients_mutex = Mutex.new
    @running = false
  end

  def start
    @logger.debug("Starting Streamable HTTP MCP transport at #{MCP_PATH}")
    @running = true
  end

  def stop
    @logger.debug("Stopping Streamable HTTP MCP transport")
    @running = false
    close_all_sse_connections
    @session_store.clear
  end

  # Rack middleware entry point
  def call(env)
    request = Rack::Request.new(env)

    return @app.call(env) unless request.path == MCP_PATH

    @server.transport = self
    handle_mcp_request(request, env)
  end

  # Called by FastMcp::Server to send responses
  # Returns the JSON as an array for Rack response body
  def send_message(message)
    json_message = message.is_a?(String) ? message : JSON.generate(message)

    # Store in buffer for request-response flow
    Thread.current[:mcp_response_buffer] = json_message

    # Also broadcast to SSE clients if any
    broadcast_to_sse_clients(json_message) if @sse_clients.any?

    # Return as array for Rack body
    [ json_message ]
  end

  private

  def handle_mcp_request(request, env)
    # Security checks
    return forbidden_response("Remote IP not allowed") unless valid_client_ip?(request)
    return forbidden_response("Origin validation failed") unless validate_origin(request, env)

    case request.request_method
    when "POST"
      handle_post_request(request, env)
    when "GET"
      handle_get_request(request, env)
    when "DELETE"
      handle_delete_request(request, env)
    when "OPTIONS"
      handle_options_request
    else
      method_not_allowed_response
    end
  end

  def handle_post_request(request, env)
    # Authenticate via Bearer token
    user = authenticate_bearer_token(request)
    return unauthorized_response("Invalid or missing API token") unless user

    # Parse JSON-RPC body
    body = request.body.read
    begin
      json_request = JSON.parse(body)
    rescue JSON::ParserError
      return bad_request_response("Parse error: Invalid JSON")
    end

    return bad_request_response("Invalid Request") unless json_request.is_a?(Hash)

    method = json_request["method"]

    # Handle Initialize (no session required)
    if method == "initialize"
      handle_initialize_request(user, json_request, request, env)
    else
      # All other requests require valid session
      handle_session_request(user, json_request, request, env)
    end
  rescue StandardError => e
    @logger.error("Error processing POST: #{e.message}\n#{e.backtrace.join("\n")}")
    internal_error_response(e.message)
  end

  def handle_initialize_request(user, json_request, request, env)
    # Get protocol version from header or default
    client_protocol_version = request.env["HTTP_MCP_PROTOCOL_VERSION"] || PROTOCOL_VERSION

    # Create new session
    session = @session_store.create(
      user_id: user.id,
      protocol_version: client_protocol_version
    )

    # Set thread-local user and session for tools
    Thread.current[:mcp_current_user] = user
    Thread.current[:mcp_session] = session

    begin
      # Clear response buffer
      Thread.current[:mcp_response_buffer] = nil

      # Extract headers for tools
      headers = extract_headers(request)

      # Process Initialize request
      @server.handle_request(JSON.generate(json_request), headers: headers)

      # Get response from buffer
      response_body = Thread.current[:mcp_response_buffer] || "{}"

      # Return with session ID header
      [
        200,
        {
          "Content-Type" => "application/json",
          "MCP-Session-Id" => session.id
        },
        [ response_body ]
      ]
    ensure
      Thread.current[:mcp_current_user] = nil
      Thread.current[:mcp_session] = nil

      Thread.current[:mcp_response_buffer] = nil
    end
  end

  def handle_session_request(user, json_request, request, env)
    session_id = request.env["HTTP_MCP_SESSION_ID"]

    # Check for missing session ID
    return bad_request_response("Missing MCP-Session-Id header") unless session_id

    # Validate session
    session = @session_store.find(session_id)
    return session_not_found_response unless session

    # Verify session belongs to authenticated user
    return forbidden_response("Session user mismatch") unless session.user_id == user.id

    # Determine if this is a notification (no id means notification)
    is_notification = json_request["id"].nil?

    # Set thread-local user and session
    Thread.current[:mcp_current_user] = user
    Thread.current[:mcp_session] = session

    begin
      # Clear response buffer
      Thread.current[:mcp_response_buffer] = nil

      # Extract headers for tools
      headers = extract_headers(request)

      # Process request
      @server.handle_request(JSON.generate(json_request), headers: headers)

      if is_notification
        # Return 202 Accepted for notifications
        [ 202, {}, [] ]
      else
        # Get response from buffer
        response_body = Thread.current[:mcp_response_buffer] || "{}"
        log_tool_errors(response_body, json_request)
        [ 200, { "Content-Type" => "application/json" }, [ response_body ] ]
      end
    ensure
      Thread.current[:mcp_current_user] = nil
      Thread.current[:mcp_session] = nil

      Thread.current[:mcp_response_buffer] = nil
    end
  end

  def handle_get_request(request, env)
    # Authenticate
    user = authenticate_bearer_token(request)
    return unauthorized_response("Invalid or missing API token") unless user

    # Require session ID for GET (SSE stream)
    session_id = request.env["HTTP_MCP_SESSION_ID"]
    return bad_request_response("Missing MCP-Session-Id header") unless session_id

    # Validate session
    session = @session_store.find(session_id)
    return session_not_found_response unless session
    return forbidden_response("Session user mismatch") unless session.user_id == user.id

    # Check for rack.hijack support
    return method_not_allowed_response("SSE not supported") unless env["rack.hijack"]

    # Handle SSE stream for server-initiated messages
    handle_sse_stream(request, env, session, user)
  end

  def handle_delete_request(request, env)
    # Authenticate
    user = authenticate_bearer_token(request)
    return unauthorized_response("Invalid or missing API token") unless user

    session_id = request.env["HTTP_MCP_SESSION_ID"]
    return bad_request_response("Missing MCP-Session-Id header") unless session_id

    session = @session_store.find(session_id)
    return session_not_found_response unless session
    return forbidden_response("Session user mismatch") unless session.user_id == user.id

    @session_store.delete(session_id)
    [ 200, { "Content-Type" => "application/json" }, [ '{"deleted":true}' ] ]
  end

  def handle_options_request
    [
      200,
      {
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, POST, DELETE, OPTIONS",
        "Access-Control-Allow-Headers" => "Content-Type, Authorization, Accept, MCP-Session-Id, MCP-Protocol-Version",
        "Access-Control-Max-Age" => "86400"
      },
      []
    ]
  end

  def handle_sse_stream(request, env, session, user)
    client_id = SecureRandom.uuid
    last_event_id = request.env["HTTP_LAST_EVENT_ID"]

    Thread.current[:mcp_current_user] = user

    env["rack.hijack"].call
    io = env["rack.hijack_io"]

    begin
      setup_sse_connection(client_id, io, session, last_event_id)
      start_sse_keep_alive(client_id, io, session)
    rescue StandardError => e
      @logger.error("SSE setup error: #{e.message}")
      io.close rescue nil
    end

    [ -1, {}, [] ]
  ensure
    Thread.current[:mcp_current_user] = nil
    Thread.current[:mcp_session] = nil
  end

  def setup_sse_connection(client_id, io, session, _last_event_id)
    mutex = Mutex.new

    # Send HTTP headers
    mutex.synchronize do
      io.write("HTTP/1.1 200 OK\r\n")
      SSE_HEADERS.each { |k, v| io.write("#{k}: #{v}\r\n") }
      io.write("\r\n")
      io.write(": SSE connection established\n\n")
      io.write("retry: 3000\n\n")
      io.flush
    end

    # Prime stream with initial event
    event_id = session.next_event_id
    mutex.synchronize do
      io.write("id: #{event_id}\ndata: \n\n")
      io.flush
    end

    register_sse_client(client_id, io, mutex, session.id)
  end

  def start_sse_keep_alive(client_id, io, session)
    Thread.new do
      ping_count = 0

      while @running && !io.closed?
        begin
          client = @sse_clients[client_id]
          break unless client

          mutex = client[:mutex]
          mutex.synchronize do
            ping_count += 1
            io.write(": keep-alive #{ping_count}\n\n")
            io.flush

            if (ping_count % 5).zero?
              event_id = session.next_event_id
              ping_message = { jsonrpc: "2.0", method: "ping", id: rand(1_000_000) }
              io.write("id: #{event_id}\ndata: #{JSON.generate(ping_message)}\n\n")
              io.flush
            end
          end

          sleep 1
        rescue StandardError => e
          @logger.debug("Keep-alive error for #{client_id}: #{e.message}")
          break
        end
      end

      unregister_sse_client(client_id)
      io.close rescue nil
    end
  end

  # Authentication — Doorkeeper OAuth tokens (claude.ai connector) first, then
  # ApiToken (Claude Code, Luo Ji).

  def authenticate_bearer_token(request)
    auth_header = request.env["HTTP_AUTHORIZATION"]
    return nil unless auth_header&.start_with?("Bearer ")

    token = auth_header.sub("Bearer ", "")

    doorkeeper_token = Doorkeeper::AccessToken.by_token(token)
    if doorkeeper_token&.accessible?
      return User.find_by(id: doorkeeper_token.resource_owner_id)
    end

    api_token = ApiToken.find_by_token(token)
    return nil unless api_token
    return nil if api_token.expired?

    api_token.touch_last_used!
    api_token.user
  end

  def extract_headers(request)
    request.env.select { |k, _v| k.start_with?("HTTP_") }
           .transform_keys { |k| k.sub("HTTP_", "").downcase.tr("_", "-") }
  end

  # SSE client management

  def register_sse_client(client_id, stream, mutex, session_id)
    @sse_clients_mutex.synchronize do
      @sse_clients[client_id] = {
        stream: stream,
        mutex: mutex,
        session_id: session_id,
        connected_at: Time.current
      }
    end
  end

  def unregister_sse_client(client_id)
    @sse_clients_mutex.synchronize do
      @sse_clients.delete(client_id)
    end
  end

  def broadcast_to_sse_clients(json_message)
    clients_to_remove = []

    @sse_clients_mutex.synchronize do
      @sse_clients.each do |client_id, client|
        stream = client[:stream]
        mutex = client[:mutex]
        next if stream.nil? || stream.closed?

        begin
          mutex.synchronize do
            stream.write("data: #{json_message}\n\n")
            stream.flush
          end
        rescue StandardError => e
          @logger.info("Client #{client_id} disconnected: #{e.message}")
          clients_to_remove << client_id
        end
      end
    end

    clients_to_remove.each { |id| unregister_sse_client(id) }
  end

  def close_all_sse_connections
    @sse_clients_mutex.synchronize do
      @sse_clients.each_value do |client|
        client[:stream].close rescue nil
      end
      @sse_clients.clear
    end
  end

  # Security helpers

  def valid_client_ip?(request)
    return true unless @localhost_only

    @allowed_ips.include?(request.ip)
  end

  def validate_origin(request, env)
    origin = env["HTTP_ORIGIN"]
    origin = env["HTTP_REFERER"] || request.host if origin.nil? || origin.empty?

    hostname = extract_hostname(origin)
    return true if hostname.nil? || @allowed_origins.empty?

    @allowed_origins.any? do |allowed|
      if allowed.is_a?(Regexp)
        hostname.match?(allowed)
      else
        hostname == allowed
      end
    end
  end

  def extract_hostname(url)
    return nil if url.nil? || url.empty?

    begin
      has_scheme = url.match?(%r{^[a-zA-Z][a-zA-Z0-9+.-]*://})
      parsing_url = has_scheme ? url : "http://#{url}"
      uri = URI.parse(parsing_url)
      return nil if uri.host.nil? || uri.host.empty?

      uri.host
    rescue URI::InvalidURIError
      url.split(":").first if url.match?(%r{^([^:/]+)(:\d+)?$})
    end
  end

  # Error logging

  def log_tool_errors(response_body, json_request)
    response = JSON.parse(response_body)
    return unless response.is_a?(Hash)

    # Check for JSON-RPC error responses (tool execution failures caught by fast-mcp)
    if response["error"]
      tool_name = json_request.dig("params", "name") || json_request["method"]
      @logger.error("MCP tool error [#{tool_name}]: #{response["error"]["message"]}")
    end

    # Check for tool results with isError flag (tool-level errors returned as content)
    if response.dig("result", "isError")
      tool_name = json_request.dig("params", "name") || json_request["method"]
      error_text = Array(response.dig("result", "content"))
                     .select { |c| c["type"] == "text" }
                     .map { |c| c["text"] }
                     .join("\n")
      @logger.error("MCP tool error [#{tool_name}]: #{error_text}")
    end
  rescue JSON::ParserError
    # Response wasn't valid JSON, nothing to log
  end

  # Response helpers

  def unauthorized_response(message)
    body = JSON.generate({
      jsonrpc: "2.0",
      error: { code: -32000, message: "Unauthorized: #{message}" },
      id: nil
    })
    [ 401, { "Content-Type" => "application/json" }, [ body ] ]
  end

  def forbidden_response(message)
    body = JSON.generate({
      jsonrpc: "2.0",
      error: { code: -32600, message: "Forbidden: #{message}" },
      id: nil
    })
    [ 403, { "Content-Type" => "application/json" }, [ body ] ]
  end

  def bad_request_response(message)
    body = JSON.generate({
      jsonrpc: "2.0",
      error: { code: -32600, message: message },
      id: nil
    })
    [ 400, { "Content-Type" => "application/json" }, [ body ] ]
  end

  def session_not_found_response
    body = JSON.generate({
      jsonrpc: "2.0",
      error: { code: -32600, message: "Session not found or expired" },
      id: nil
    })
    [ 404, { "Content-Type" => "application/json" }, [ body ] ]
  end

  def method_not_allowed_response(message = "Method not allowed")
    body = JSON.generate({
      jsonrpc: "2.0",
      error: { code: -32601, message: message },
      id: nil
    })
    [ 405, { "Content-Type" => "application/json" }, [ body ] ]
  end

  def internal_error_response(message)
    body = JSON.generate({
      jsonrpc: "2.0",
      error: { code: -32603, message: "Internal error: #{message}" },
      id: nil
    })
    [ 500, { "Content-Type" => "application/json" }, [ body ] ]
  end
end
