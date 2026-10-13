require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with just email and password" do
    user = User.new(email_address: "new@example.com", password: "password123")
    assert user.valid?
  end

  test "invalid without email" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "invalid with malformed email" do
    user = User.new(email_address: "not-an-email", password: "password123")
    assert_not user.valid?
  end

  test "normalizes email to lowercase" do
    user = User.create!(email_address: "  Foo@Example.COM  ", password: "password123")
    assert_equal "foo@example.com", user.email_address
  end

  # Stripe connection helpers
  test "stripe_connected? is false when no key set" do
    user = User.new(email_address: "x@example.com")
    assert_not user.stripe_connected?
    assert_not user.stripe_account_verified?
  end

  test "stripe_connected? is true when key is set, even if not verified" do
    user = User.new(email_address: "x@example.com", stripe_api_key: "rk_test_abcdefghij")
    assert user.stripe_connected?
    assert_not user.stripe_account_verified?
  end

  test "stripe_account_verified? requires both key and account id" do
    user = User.new(
      email_address: "x@example.com",
      stripe_api_key: "rk_test_abcdefghij",
      stripe_account_id: "acct_123"
    )
    assert user.stripe_account_verified?
  end

  test "stripe_masked_key shows prefix and last 4 chars" do
    user = User.new(
      email_address: "x@example.com",
      stripe_api_key: "rk_test_abcdefghij",
      stripe_api_key_prefix: "rk_test_",
      stripe_api_key_last4: "ghij"
    )
    assert_equal "rk_test_...ghij", user.stripe_masked_key
  end

  test "stripe_masked_key is nil when no key" do
    user = User.new(email_address: "x@example.com")
    assert_nil user.stripe_masked_key
  end

  # Key format validation
  test "accepts a well-formed test restricted key" do
    user = User.new(email_address: "x@example.com", password: "password123", stripe_api_key: "rk_test_AbCdEf123456")
    assert user.valid?, user.errors.full_messages.inspect
  end

  test "accepts a well-formed live restricted key" do
    user = User.new(email_address: "x@example.com", password: "password123", stripe_api_key: "rk_live_AbCdEf123456")
    assert user.valid?, user.errors.full_messages.inspect
  end

  test "rejects a secret key (sk_...)" do
    user = User.new(email_address: "x@example.com", password: "password123", stripe_api_key: "sk_test_AbCdEf123456")
    assert_not user.valid?
    assert user.errors[:stripe_api_key].any? { |m| m.include?("restricted key") }
  end

  test "rejects a publishable key (pk_...)" do
    user = User.new(email_address: "x@example.com", password: "password123", stripe_api_key: "pk_test_AbCdEf123456")
    assert_not user.valid?
  end

  test "rejects garbage input" do
    user = User.new(email_address: "x@example.com", password: "password123", stripe_api_key: "definitely-not-a-stripe-key")
    assert_not user.valid?
  end

  test "treats empty string as 'no key set'" do
    # Empty string is treated as a no-op (the controller short-circuits on blank
    # before reaching the model, but the model should not blow up on it).
    user = User.new(email_address: "x@example.com", password: "password123", stripe_api_key: "")
    assert user.valid?
    assert_not user.stripe_connected?
  end

  test "clear_stripe_connection! wipes all stripe fields" do
    user = User.create!(
      email_address: "x@example.com",
      password: "password123",
      stripe_api_key: "rk_test_AbCdEf123456",
      stripe_api_key_prefix: "rk_test_",
      stripe_api_key_last4: "3456",
      stripe_account_id: "acct_999",
      stripe_account_label: "Acme",
      stripe_account_country: "DK",
      stripe_account_default_currency: "dkk",
      stripe_connected_at: Time.current
    )
    user.clear_stripe_connection!
    user.reload
    assert_nil user.stripe_api_key
    assert_nil user.stripe_api_key_prefix
    assert_nil user.stripe_api_key_last4
    assert_nil user.stripe_account_id
    assert_nil user.stripe_account_label
    assert_nil user.stripe_account_country
    assert_nil user.stripe_account_default_currency
    assert_nil user.stripe_connected_at
  end

  test "stripe_api_key is encrypted at rest" do
    user = User.create!(
      email_address: "enc@example.com",
      password: "password123",
      stripe_api_key: "rk_test_supersecretvalue"
    )
    raw_row = ActiveRecord::Base.connection.execute("SELECT stripe_api_key FROM users WHERE id = #{user.id}").first
    # The raw column should NOT contain the plaintext we just stored.
    refute_includes raw_row["stripe_api_key"], "supersecretvalue"
    # And the model attribute should round-trip the original value.
    assert_equal "rk_test_supersecretvalue", user.reload.stripe_api_key
  end
end
