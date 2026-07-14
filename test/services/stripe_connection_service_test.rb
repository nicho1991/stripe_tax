require "test_helper"
require "minitest/mock"

class StripeConnectionServiceTest < ActiveSupport::TestCase
  # ------------------------------------------------------------------
  # Helper: build a chainable fake client that responds to
  # client.v1.accounts.retrieve with the given account.
  # ------------------------------------------------------------------
  def fake_stripe_client(account)
    accounts = Object.new
    accounts.define_singleton_method(:retrieve) { |*_args| account }
    v1 = Object.new
    v1.define_singleton_method(:accounts) { accounts }
    client = Object.new
    client.define_singleton_method(:v1) { v1 }
    client
  end

  def fake_stripe_client_raising(error)
    accounts = Object.new
    accounts.define_singleton_method(:retrieve) { |*_args| raise error }
    v1 = Object.new
    v1.define_singleton_method(:accounts) { accounts }
    client = Object.new
    client.define_singleton_method(:v1) { v1 }
    client
  end

  def fake_account(id: "acct_123", name: "Acme Inc", display: nil, email: "ops@acme.test", country: "DK", currency: "dkk", livemode: false)
    business_profile = Struct.new(:name).new(name)
    dashboard = Struct.new(:display_name).new(display)
    settings = Struct.new(:dashboard).new(dashboard)
    Struct.new(:id, :business_profile, :settings, :email, :country, :default_currency, :livemode).new(
      id, business_profile, settings, email, country, currency, livemode
    )
  end

  # ------------------------------------------------------------------
  # Real-constructor smoke test (catches Stripe::Client vs Stripe::StripeClient
  # regressions if we ever upgrade the gem). Do NOT stub build_client in this
  # one — we want the real SDK class path exercised end to end.
  # ------------------------------------------------------------------
  test "build_client returns a real Stripe::StripeClient" do
    client = StripeConnectionService.build_client("rk_test_dummy_key_for_smoke_test")
    assert_instance_of Stripe::StripeClient, client
    assert_respond_to client, :v1
    assert_respond_to client.v1, :accounts
  end

  # ------------------------------------------------------------------
  # test_connection: no key configured
  # ------------------------------------------------------------------
  test "test_connection fails gracefully when user has no key" do
    user = User.create!(email_address: "nokey@example.com", password: "password123")
    result = StripeConnectionService.test_connection(user)
    assert_equal false, result[:ok]
    assert_match(/no stripe api key/i, result[:error])
  end

  # ------------------------------------------------------------------
  # test_connection: success path
  # ------------------------------------------------------------------
  test "test_connection caches account info on success" do
    user = User.create!(
      email_address: "ok@example.com",
      password: "password123",
      stripe_api_key: "rk_test_AbCdEf123456",
      stripe_api_key_prefix: "rk_test_",
      stripe_api_key_last4: "3456"
    )

    fake = fake_stripe_client(fake_account(name: "Acme Inc", country: "DK", currency: "dkk"))

    StripeConnectionService.stub :build_client, fake do
      result = StripeConnectionService.test_connection(user.reload)
      assert result[:ok], result.inspect
      assert_equal "acct_123", result[:account][:account_id]
      assert_equal "Acme Inc", result[:account][:label]
      assert_equal "DK", result[:account][:country]
      assert_equal "dkk", result[:account][:default_currency]
    end

    user.reload
    assert_equal "acct_123", user.stripe_account_id
    assert_equal "Acme Inc", user.stripe_account_label
    assert_equal "DK", user.stripe_account_country
    assert_equal "dkk", user.stripe_account_default_currency
    assert_not_nil user.stripe_connected_at
  end

  # ------------------------------------------------------------------
  # test_connection: falls back to settings.dashboard.display_name
  # ------------------------------------------------------------------
  test "test_connection falls back to dashboard display name" do
    user = User.create!(
      email_address: "fb1@example.com",
      password: "password123",
      stripe_api_key: "rk_test_AbCdEf123456"
    )

    fake = fake_stripe_client(fake_account(name: nil, display: "Display Co"))
    StripeConnectionService.stub :build_client, fake do
      result = StripeConnectionService.test_connection(user.reload)
      assert result[:ok]
      assert_equal "Display Co", result[:account][:label]
    end
  end

  # ------------------------------------------------------------------
  # test_connection: falls back to email
  # ------------------------------------------------------------------
  test "test_connection falls back to email when no name fields" do
    user = User.create!(
      email_address: "fb2@example.com",
      password: "password123",
      stripe_api_key: "rk_test_AbCdEf123456"
    )

    fake = fake_stripe_client(fake_account(name: "", display: "", email: "fallback@example.com"))
    StripeConnectionService.stub :build_client, fake do
      result = StripeConnectionService.test_connection(user.reload)
      assert result[:ok]
      assert_equal "fallback@example.com", result[:account][:label]
    end
  end

  # ------------------------------------------------------------------
  # test_connection: Stripe::AuthenticationError
  # ------------------------------------------------------------------
  test "test_connection returns friendly error on auth failure" do
    user = User.create!(
      email_address: "bad@example.com",
      password: "password123",
      stripe_api_key: "rk_test_AbCdEf123456"
    )

    fake = fake_stripe_client_raising(Stripe::AuthenticationError.new("Invalid API Key"))
    StripeConnectionService.stub :build_client, fake do
      result = StripeConnectionService.test_connection(user.reload)
      assert_equal false, result[:ok]
      assert_match(/rejected the api key/i, result[:error])
    end
  end

  # ------------------------------------------------------------------
  # test_connection: Stripe::PermissionError
  # ------------------------------------------------------------------
  test "test_connection returns friendly error on permission error" do
    user = User.create!(
      email_address: "perm@example.com",
      password: "password123",
      stripe_api_key: "rk_test_AbCdEf123456"
    )

    fake = fake_stripe_client_raising(Stripe::PermissionError.new("Missing required permission"))
    StripeConnectionService.stub :build_client, fake do
      result = StripeConnectionService.test_connection(user.reload)
      assert_equal false, result[:ok]
      assert_match(/missing required permissions/i, result[:error])
    end
  end

  # ------------------------------------------------------------------
  # test_connection: Stripe::APIConnectionError
  # ------------------------------------------------------------------
  test "test_connection returns friendly error on network failure" do
    user = User.create!(
      email_address: "net@example.com",
      password: "password123",
      stripe_api_key: "rk_test_AbCdEf123456"
    )

    fake = fake_stripe_client_raising(Stripe::APIConnectionError.new("Could not connect"))
    StripeConnectionService.stub :build_client, fake do
      result = StripeConnectionService.test_connection(user.reload)
      assert_equal false, result[:ok]
      assert_match(/could not reach stripe/i, result[:error])
    end
  end

  # ------------------------------------------------------------------
  # test_connection: doesn't wipe the saved key on failure
  # ------------------------------------------------------------------
  test "test_connection does not wipe the saved key when the call fails" do
    user = User.create!(
      email_address: "keep@example.com",
      password: "password123",
      stripe_api_key: "rk_test_AbCdEf123456"
    )

    fake = fake_stripe_client_raising(Stripe::AuthenticationError.new("nope"))
    StripeConnectionService.stub :build_client, fake do
      StripeConnectionService.test_connection(user.reload)
    end

    user.reload
    assert_equal "rk_test_AbCdEf123456", user.stripe_api_key
    assert_nil user.stripe_account_id
  end
end
