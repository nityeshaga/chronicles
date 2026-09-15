# This migration comes from redpen (originally 20260915000001)
class CreateRedpenNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :redpen_notes do |t|
      # Attribution only: who left the note. Polymorphic so any host user class fits,
      # and no foreign key so the engine never assumes a table name.
      t.references :author, polymorphic: true, null: false
      # The page is its path; the element is a CSS selector into it.
      t.string :path, null: false, index: true
      t.string :selector, null: false
      t.string :snippet
      t.text :body, null: false
      t.datetime :resolved_at
      t.text :resolution
      t.timestamps
    end
  end
end
