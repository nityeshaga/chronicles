# This migration comes from redpen (originally 20261123000001)
class AddFragmentToRedpenNotes < ActiveRecord::Migration[8.0]
  def change
    # A page that routes in its fragment is many pages on one path: "#/tcp/4". Null for
    # every other note, which belongs to the whole path.
    add_column :redpen_notes, :fragment, :string
  end
end
