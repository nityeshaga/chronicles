class AddDescriptionToTags < ActiveRecord::Migration[8.1]
  def change
    add_column :tags, :description, :text
  end
end
