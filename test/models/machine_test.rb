require "test_helper"

class MachineTest < ActiveSupport::TestCase
  test "machines shelve newest-shipped first" do
    dates = Machine.all.map(&:shipped_on)
    assert_equal dates.sort.reverse, dates
  end

  test "every machine brings its own landing-page screenshot" do
    Machine.all.each do |machine|
      assert Rails.root.join("app/assets/images/machines/#{machine.slug}.jpg").exist?,
        "missing screenshot for #{machine.slug}"
    end
  end
end
