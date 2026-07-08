require "test_helper"

class StripeClientTest < ActiveSupport::TestCase
  setup do
    StripeClient.reset!
  end

  teardown do
    StripeClient.reset!
  end

  test "configured? returns false when no key resolved" do
    # ENV-based fallback is what `resolve` falls through to when no
    # caller key is given; clear it for this test.
    original_env = ENV["STRIPE_SECRET_KEY"]
    ENV["STRIPE_SECRET_KEY"] = nil
    refute StripeClient.configured?(key: nil)
  ensure
    ENV["STRIPE_SECRET_KEY"] = original_env
  end

  test "configured? returns true when caller-provided key is present" do
    assert StripeClient.configured?(key: "sk_test_present")
  end

  test "client raises CredentialsMissing when key is blank" do
    err = assert_raises(PayoutImporter::CredentialsMissing) do
      StripeClient.client(key: "")
    end
    assert_match(/credentials missing/i, err.message)
  end

  test "client raises CredentialsMissing when key is nil" do
    assert_raises(PayoutImporter::CredentialsMissing) do
      StripeClient.client(key: nil)
    end
  end

  # REGRESSION GUARD — the build_client path constructs a real
  # Stripe::StripeClient (stripe-ruby 19.x). Earlier code referenced
  # Stripe::Client which is not defined in 19.x; this would NameError
  # at runtime even though all stubbed tests passed. By calling the
  # real build path here we catch any future "wrong class name" mistake.
  test "client builds a real Stripe::StripeClient for a non-blank key" do
    client = StripeClient.client(key: "sk_test_unit_test_key")
    assert_instance_of Stripe::StripeClient, client
    # Catches "we accidentally swapped to legacy shape" too:
    assert_respond_to client.v1, :payouts
    assert_respond_to client.v1, :balance_transactions
  end

  test "client memoizes per key — same key returns same instance" do
    a = StripeClient.client(key: "sk_test_memoized")
    b = StripeClient.client(key: "sk_test_memoized")
    assert_same a, b
  end

  test "client memoizes independently per key" do
    a = StripeClient.client(key: "sk_test_user_a")
    b = StripeClient.client(key: "sk_test_user_b")
    refute_same a, b
  end

  test "reset! clears the memoization cache" do
    a = StripeClient.client(key: "sk_test_after_reset")
    StripeClient.reset!
    b = StripeClient.client(key: "sk_test_after_reset")
    refute_same a, b
  end
end