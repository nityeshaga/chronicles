class CreateHtmlCards < ActiveRecord::Migration[8.1]
  def change
    create_table :html_cards do |t|
      t.text :content, null: false
      t.timestamps
    end
  end
end
