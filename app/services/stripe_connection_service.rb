class StripeConnectionService
  # Wraps the stripe-ruby SDK so the rest of the app can ask
  # "is this user's stored key valid?" without touching the SDK directly.
  #
  # Two entry points:
  #   .build_client(api_key)  - returns a Stripe::StripeClient (used by callers
  #                              that want to hit other endpoints later).
  #   .test_connection(user)  - verifies the user's saved key by calling
  #                              account.retrieve and caches the account info.

  TEST_MODE_HINT = "rk_test_"
  LIVE_MODE_HINT = "rk_live_"

  def self.build_client(api_key)
    # stripe-ruby 15.x uses Stripe::StripeClient (Stripe::Client was the legacy
    # pre-13.0 class). If we ever upgrade and the class moves, the assertion in
    # test/services/stripe_connection_service_test.rb will catch it.
    Stripe::StripeClient.new(api_key)
  end

  def self.test_connection(user)
    return failure("No Stripe API key configured for this user.") unless user.stripe_api_key.present?

    client = build_client(user.stripe_api_key)
    account = client.v1.accounts.retrieve

    user.update!(
      stripe_account_id: account.id,
      stripe_account_label: account.business_profile&.name.presence || account.settings&.dashboard&.display_name.presence || account.email,
      stripe_account_country: account.country,
      stripe_account_default_currency: account.default_currency,
      stripe_connected_at: Time.current
    )

    success(account_summary(account))
  rescue Stripe::AuthenticationError => e
    failure("Stripe rejected the API key: #{e.message}")
  rescue Stripe::PermissionError => e
    failure("The connected Stripe key is missing required permissions: #{e.message}")
  rescue Stripe::APIConnectionError => e
    failure("Could not reach Stripe: #{e.message}")
  rescue Stripe::StripeError => e
    failure("Stripe error: #{e.message}")
  end

  def self.account_summary(account)
    {
      account_id: account.id,
      label: account.business_profile&.name.presence || account.settings&.dashboard&.display_name.presence || account.email,
      country: account.country,
      default_currency: account.default_currency,
      livemode: account.respond_to?(:livemode) ? account.livemode : account.id.start_with?("acct_") && !account.id.include?("test")
    }
  end

  def self.success(payload)
    { ok: true, account: payload }
  end

  def self.failure(message)
    { ok: false, error: message }
  end
end
