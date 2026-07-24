require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "current returns the single site-identity row" do
    assert_equal settings(:default), Setting.current
    assert_equal settings(:default).site_title, Setting.current.site_title
    assert_equal settings(:default).production_host, Setting.current.production_host
  end
end
