# frozen_string_literal: true

# Represents an MCP session with user context and event tracking.
# Persisted to database so sessions survive server restarts.
class McpSession < ApplicationRecord
  belongs_to :user

  before_create :generate_session_id
  before_create :set_last_activity

  def expired?(ttl = 1.hour)
    Time.current - last_activity_at > ttl
  end

  def touch!
    update_column(:last_activity_at, Time.current)
  end

  # Get next event ID for SSE streaming
  def next_event_id
    increment!(:event_counter)
    "#{id}:#{event_counter}"
  end

  def self.cleanup_expired(ttl = 1.hour)
    where("last_activity_at < ?", Time.current - ttl).delete_all
  end

  private
    def generate_session_id
      self.id = "urn:uuid:#{SecureRandom.uuid}"
    end

    def set_last_activity
      self.last_activity_at ||= Time.current
    end
end
