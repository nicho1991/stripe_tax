# Memoized Stripe SDK client wrapper. Modern SDK style only — callers
# use `StripeClient.client.v1.balance_transactions.list(...)`, NOT the
# legacy top-level `Stripe::BalanceTransaction.list(...)` shape that
# stripe-ruby v13+ deprecates.
#
# Credentials come from the calling `key:` argument — there is no
# global resolution. The `:stripe_api` branch of `PayoutImporter` and
# the `payouts#fetch` controller action both pass the current user's
# `stripe_secret_key` through. Single-user dev workflows that haven't
# yet stored a key in the DB can fall back to `ENV["STRIPE_SECRET_KEY"]`
# (and ultimately `Rails.application.credentials.dig(:stripe,
# :secret_key)`) — see `StripeClient.configured?(key:)` for the
# resolution helper used by callers.
#
# Tests: use StripeClient.reset! to clear the memoized client between
# examples when stubbing different keys. The instance cache is keyed by
# `key` so multiple users with different keys don't collide.
class StripeClient
  class << self
    def client(key:)
      @clients ||= {}
      @clients[key] ||= build_client(key)
    end

    def configured?(key:)
      resolve(key).present?
    end

    def reset!
      @clients = {}
    end

    private

    def build_client(key)
      raise PayoutImporter::CredentialsMissing, "Stripe API credentials missing" if key.blank?

      # stripe-ruby 19.x: the modern client class is Stripe::StripeClient
      # (constructed with the API key as a positional arg). Older docs
      # reference `Stripe::Client` which is not defined in this version.
      Stripe::StripeClient.new(key)
    end

    # Caller-provided key first, then env fallback (dev/CI), then
    # encrypted credentials (single-account bootstrap). Returns nil
    # for any unconfigured case so callers can render a friendly
    # message rather than 500.
    def resolve(key)
      key.presence || ENV["STRIPE_SECRET_KEY"].presence ||
        Rails.application.credentials.dig(:stripe, :secret_key).presence
    end
  end
end
