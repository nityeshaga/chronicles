class CreateMcpSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_sessions, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.references :user, null: false, foreign_key: true
      t.string :protocol_version, default: "2025-11-25"
      t.integer :event_counter, default: 0
      t.datetime :last_activity_at, null: false

      t.timestamps
    end

    add_index :mcp_sessions, :last_activity_at
  end
end
