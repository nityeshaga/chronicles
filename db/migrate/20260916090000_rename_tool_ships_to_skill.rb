# The tools were skills all along: prompts and abilities taught to an AI employee. The
# kind is a string column, so the rename is a data move, not a schema change.
class RenameToolShipsToSkill < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE ships SET kind = 'skill' WHERE kind = 'tool'"
  end

  def down
    execute "UPDATE ships SET kind = 'tool' WHERE kind = 'skill'"
  end
end
