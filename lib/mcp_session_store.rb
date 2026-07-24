# frozen_string_literal: true

# Database-backed MCP session store that survives server restarts.
# Uses the McpSession ActiveRecord model for persistence.
class McpSessionStore
  def initialize(ttl: 1.hour)
    @ttl = ttl
  end

  def create(user_id:, protocol_version: "2025-11-25")
    ::McpSession.create!(
      user_id: user_id,
      protocol_version: protocol_version
    )
  end

  def find(session_id)
    session = ::McpSession.find_by(id: session_id)
    return nil unless session
    return nil if session.expired?(@ttl)

    session.touch!
    session
  end

  def delete(session_id)
    ::McpSession.where(id: session_id).delete_all
  end

  def clear
    ::McpSession.delete_all
  end

  def cleanup_expired
    ::McpSession.cleanup_expired(@ttl)
  end

  def size
    ::McpSession.count
  end
end
