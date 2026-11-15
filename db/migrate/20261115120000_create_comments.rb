class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :doc, null: false, foreign_key: { to_table: :posts, on_delete: :cascade }
      t.references :parent, foreign_key: { to_table: :comments, on_delete: :cascade }
      t.string :author_name, null: false
      t.text :body, null: false
      t.text :quote
      t.string :prefix
      t.datetime :resolved_at

      t.timestamps
    end
  end
end
