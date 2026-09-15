class CreateShips < ActiveRecord::Migration[8.1]
  def change
    create_table :ships do |t|
      t.integer :number
      t.date :shipped_on, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.text :blurb
      t.string :built_by, null: false
      t.string :check_it_out_url
      t.text :prompt
      t.references :how_built_post, foreign_key: { to_table: :posts, on_delete: :nullify }
      t.references :post, foreign_key: { on_delete: :nullify }
      t.string :x_status_id
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.timestamps
    end

    add_index :ships, :number, unique: true
    add_index :ships, [ :status, :shipped_on ]
  end
end
