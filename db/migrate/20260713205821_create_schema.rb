class CreateSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :users, :email_address, unique: true

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :user_agent
      t.string :ip_address
      t.timestamps
    end

    create_table :posts do |t|
      t.string :type, null: false, default: "Post"
      t.string :title, null: false
      t.string :slug, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.string :feature_image
      t.string :feature_image_caption
      t.text :excerpt
      t.string :meta_title
      t.string :meta_description
      t.text :raw_source
      t.timestamps
    end
    add_index :posts, :slug, unique: true
    add_index :posts, :status
    add_index :posts, [ :type, :status ]

    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :tags, :slug, unique: true

    create_table :taggings do |t|
      t.references :post, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :taggings, [ :post_id, :tag_id ], unique: true
  end
end
