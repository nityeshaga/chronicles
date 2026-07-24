require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "authenticates with the right password" do
    assert User.authenticate_by(email_address: "nityesh@example.com", password: "secret123")
  end

  test "rejects the wrong password" do
    assert_nil User.authenticate_by(email_address: "nityesh@example.com", password: "nope")
  end

  test "normalizes the email address" do
    user = User.create!(name: "X", email_address: "  MixedCase@Example.COM ", password: "secret123")
    assert_equal "mixedcase@example.com", user.email_address
  end

  test "email address is unique" do
    assert_raises(ActiveRecord::RecordInvalid) do
      User.create!(name: "Dup", email_address: "nityesh@example.com", password: "secret123")
    end
  end
end
