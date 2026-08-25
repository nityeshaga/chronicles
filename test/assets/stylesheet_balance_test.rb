require "test_helper"

# A browser parses CSS forgivingly: one unclosed block swallows every rule after it, with no
# error anywhere. The merge that produced #45 left exactly that — the settings panel and the
# publish popover simply stopped being styled. Rails has no CSS compiler to catch it, so this
# does the one check that would have: every block opened is closed, in every stylesheet.
class StylesheetBalanceTest < ActiveSupport::TestCase
  Dir[Rails.root.join("app/assets/stylesheets/*.css")].each do |path|
    test "#{File.basename(path)} closes every block it opens" do
      css = File.read(path).gsub(%r{/\*.*?\*/}m, "").gsub(/"(?:\\.|[^"])*"|'(?:\\.|[^'])*'/, "")
      depth = 0
      css.each_char.with_index do |char, index|
        depth += 1 if char == "{"
        depth -= 1 if char == "}"
        assert depth >= 0, "#{File.basename(path)}: stray closing brace near byte #{index}"
      end
      assert_equal 0, depth, "#{File.basename(path)}: #{depth} block(s) never closed"
    end
  end
end
