# The red pen moved into the redpen-rails gem. Its notes go with it: same columns, the
# author now polymorphic, the old table gone.
class MoveNotesToRedpen < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO redpen_notes (author_type, author_id, path, selector, snippet, body, resolved_at, resolution, created_at, updated_at)
      SELECT 'User', user_id, path, selector, snippet, body, resolved_at, resolution, created_at, updated_at FROM notes
    SQL
    drop_table :notes
  end

  def down
    create_table :notes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :path, null: false
      t.string :selector, null: false
      t.string :snippet
      t.text :body, null: false
      t.datetime :resolved_at
      t.text :resolution
      t.timestamps
    end
    add_index :notes, [ :user_id, :path ]
    execute <<~SQL
      INSERT INTO notes (user_id, path, selector, snippet, body, resolved_at, resolution, created_at, updated_at)
      SELECT author_id, path, selector, snippet, body, resolved_at, resolution, created_at, updated_at FROM redpen_notes WHERE author_type = 'User'
    SQL
  end
end
