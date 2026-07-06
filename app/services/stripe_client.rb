# Memoized Stripe SDK client wrapper. Modern SDK style only — callers
# use `StripeClient.client.v1.balance_transactions.list(...)`, NOT the
# legacy top-level `Stripe::BalanceTransaction.list(...)` shape that
# stripe-ruby v13+ deprecates.
#
# Credential resolution order:
#   1. Rails.application.credentials.dig(:stripe, :secret_key)  — production
#   2. ENV["STRIPE_SECRET_KEY"]                                — dev / CI fallback
#
# If neither is set, StripeClient.configured? returns false and
# PayoutImporter(:stripe_api) raises PayoutImporter::CredentialsMissing.
# The :csv branch of PayoutImporter is unaffected.
#
# Tests: use StripeClient.reset! to clear the memoized client between
# examples when stubbing different keys.
class StripeClient
  class << self
    def client
      @client ||= build_client
    end

    def configured?
      resolved_key.present?
    end

    def reset!
      @client = nil
    end

    private

    def build_client
      key = resolved_key
      raise PayoutImporter::CredentialsMissing, "Stripe API credentials missing" if key.blank?

      Stripe.api_key = key
      Stripe::Client.new
    end

    def resolved_key
      Rails.application.credentials.dig(:stripe, :secret_key).presence ||
        ENV["STRIPE_SECRET_KEY"].presence
    end
  end
end
