require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  setup { @user = users(:nityesh) }

  test "generates a plaintext token on create and stores only its digest" do
    token = @user.api_tokens.create!(name: "Claude Code")

    assert token.plain_token.present?
    assert_equal 48, token.plain_token.length
    assert_equal Digest::SHA256.hexdigest(token.plain_token), token.token_digest
    assert_not_equal token.plain_token, token.token_digest
  end

  test "the plaintext token is never persisted" do
    token = @user.api_tokens.create!(name: "Claude Code")

    assert_nil ApiToken.column_names.find { |c| c == "token" || c == "plain_token" }
    assert_nil ApiToken.find(token.id).plain_token
  end

  test "find_by_token resolves by digest and ignores blanks" do
    token = @user.api_tokens.create!(name: "Claude Code")

    assert_equal token, ApiToken.find_by_token(token.plain_token)
    assert_nil ApiToken.find_by_token("wrong-token")
    assert_nil ApiToken.find_by_token(nil)
    assert_nil ApiToken.find_by_token("")
  end

  test "requires a name" do
    token = @user.api_tokens.build(name: "")
    assert_not token.valid?
    assert_includes token.errors[:name], "can't be blank"
  end

  test "the unique index rejects a duplicate digest" do
    existing = @user.api_tokens.create!(name: "one")
    # save(validate: false) skips the create callback that would otherwise mint a fresh
    # digest, so the collision reaches the database and its unique index.
    duplicate = @user.api_tokens.build(name: "two", token_digest: existing.token_digest)

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end

  test "expired? tracks the expiry window" do
    assert_not @user.api_tokens.create!(name: "no expiry").expired?
    assert_not @user.api_tokens.create!(name: "future", expires_at: 1.hour.from_now).expired?
    assert @user.api_tokens.create!(name: "past", expires_at: 1.hour.ago).expired?
  end

  test "touch_last_used! stamps last_used_at without running validations" do
    token = @user.api_tokens.create!(name: "Claude Code")
    assert_nil token.last_used_at

    freeze_time do
      token.touch_last_used!
      assert_equal Time.current, token.reload.last_used_at
    end
  end
end
