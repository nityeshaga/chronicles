# index.html used to be the explorable's raw_html while every other file was an asset —
# a special case every lookup had to know about (and one forgot: /slug/index.html 404'd).
# Now it is an asset like the rest; move the stored documents over and clear the column.
class MoveExplorableIndexIntoAssets < ActiveRecord::Migration[8.1]
  def up
    select_rows("SELECT id, raw_html FROM posts WHERE type = 'Explorable' AND raw_html IS NOT NULL").each do |id, html|
      next if select_value("SELECT 1 FROM explorable_assets WHERE explorable_id = #{id.to_i} AND path = 'index.html'")

      exec_insert "INSERT INTO explorable_assets (explorable_id, path, content_type, content, created_at, updated_at) VALUES (?, 'index.html', 'text/html', ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                  "index.html", [ bind("explorable_id", id, :integer), bind("content", html, :binary) ]
    end
    execute "UPDATE posts SET raw_html = NULL WHERE type = 'Explorable'"
  end

  def down
    select_rows("SELECT explorable_id, content FROM explorable_assets WHERE path = 'index.html'").each do |id, html|
      exec_update "UPDATE posts SET raw_html = ? WHERE id = ?", "raw_html",
                  [ bind("raw_html", html.to_s.dup.force_encoding(Encoding::UTF_8), :string), bind("id", id, :integer) ]
    end
    execute "DELETE FROM explorable_assets WHERE path = 'index.html'"
  end

  private
    def bind(name, value, type)
      ActiveRecord::Relation::QueryAttribute.new(name, value, ActiveRecord::Type.lookup(type))
    end
end
