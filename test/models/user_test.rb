require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "stripe_configured? is false when no key set" do
    @user.update_columns(stripe_secret_key: nil)
    refute @user.reload.stripe_configured?
  end

  test "stripe_configured? becomes true when the encrypted key is set" do
    @user.stripe_secret_key = "sk_test_anything"
    @user.save!
    assert @user.reload.stripe_configured?
  end

  test "stripe_secret_key is encrypted at rest (raw column != plaintext)" do
    @user.stripe_secret_key = "sk_test_supersecret"
    @user.save!
    raw = ActiveRecord::Base.connection.select_value(
      "SELECT stripe_secret_key FROM users WHERE id = #{@user.id}"
    )
    refute_includes raw.to_s, "sk_test_supersecret",
      "raw stripe_secret_key column must not contain plaintext"
    refute_includes raw.to_s, "supersecret",
      "raw stripe_secret_key column must not contain the secret"
  end

  test "stripe_secret_key round-trips through encryption" do
    @user.stripe_secret_key = "sk_test_roundtrip"
    @user.save!
    assert_equal "sk_test_roundtrip", @user.reload.stripe_secret_key
  end

  test "authenticate still works after encryption refactor" do
    # Sanity-check: adding has_secure_password + encrypts doesn't
    # collide on the User model.
    assert @user.authenticate("password")
    refute @user.authenticate("not-the-password")
  end
end
