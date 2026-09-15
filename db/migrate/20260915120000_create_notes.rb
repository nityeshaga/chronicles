class CreateNotes < ActiveRecord::Migration[8.1]
  def change
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
  end
end
