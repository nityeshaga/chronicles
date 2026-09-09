class CreateExplorableAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :explorable_assets do |t|
      t.references :explorable, null: false, foreign_key: { to_table: :posts }
      t.string :path, null: false
      t.string :content_type, null: false
      t.binary :content, null: false
      t.timestamps
    end

    add_index :explorable_assets, %i[ explorable_id path ], unique: true
  end
end
