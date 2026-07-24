class CreateSettings < ActiveRecord::Migration[8.1]
  # Frozen to this migration's schema. The app's Setting may later grow
  # validations, callbacks or renamed columns; replaying history from scratch must
  # not depend on that future shape, so the backfill talks to a throwaway model.
  class Setting < ActiveRecord::Base; end

  def up
    create_table :settings do |t|
      t.string  :site_title,        null: false
      t.string  :site_description,  null: false
      t.string  :site_logo,         null: false
      t.string  :author_name,       null: false
      t.string  :author_image,      null: false
      t.string  :author_image_full, null: false
      t.integer :author_image_size, null: false
      t.string  :author_path,       null: false
      t.string  :twitter_handle,    null: false
      t.string  :home_meta_title,   null: false
      t.string  :production_host,   null: false

      t.timestamps
    end

    # Backfill the single row with the live production values so the deploy that
    # runs this migration leaves nityesh.com byte-for-byte identical — no console
    # step, no seed run required on the existing database.
    Setting.create!(
      site_title:        "Chronicles of Nityesh",
      site_description:  "Hot takes, secret recipes, leaked memos and epic fails - from a creator building a SaaS business",
      site_logo:         "/content/images/2024/12/nityesh-com-logo-bg-removed.png",
      author_name:       "Nityesh Agarwal",
      author_image:      "/content/images/size/w160/2024/12/nityesh-headshot-2.jpeg",
      author_image_full: "/content/images/2024/12/nityesh-headshot-2.jpeg",
      author_image_size: 465,
      author_path:       "author/nityesh/",
      twitter_handle:    "@nityeshaga",
      home_meta_title:   "Nityesh Agarwal - founder of Curated Connections",
      production_host:   "nityesh.com"
    )
  end

  def down
    drop_table :settings
  end
end
