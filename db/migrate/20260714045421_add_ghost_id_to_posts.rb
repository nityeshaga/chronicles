class AddGhostIdToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :ghost_id, :string
  end
end
