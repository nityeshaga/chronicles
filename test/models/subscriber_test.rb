require "test_helper"

class SubscriberTest < ActiveSupport::TestCase
  test "normalizes the email by stripping and downcasing" do
    subscriber = Subscriber.create!(email: "  New@Example.COM ")
    assert_equal "new@example.com", subscriber.email
  end

  test "requires an email" do
    subscriber = Subscriber.new(email: "")
    assert_not subscriber.valid?
    assert_includes subscriber.errors[:email], "can't be blank"
  end

  test "rejects a malformed email" do
    assert_not Subscriber.new(email: "not-an-email").valid?
  end

  test "enforces uniqueness after normalization" do
    Subscriber.create!(email: "dup@example.com")
    duplicate = Subscriber.new(email: "DUP@example.com ")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end
end
