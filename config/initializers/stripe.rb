# Pin Stripe API version at boot. The stripe-ruby gem (~> 19.3)
# defaults to the version baked into the SDK at release; pinning here
# insulates the app from surprise behavior changes when we upgrade
# the gem in the future. The pinned version is the one stripe-ruby
# 19.3.0 was built against (per its bundled .api_version).
#
# Phase 1: only used by StripeClient (and downstream StripePayoutFetcher,
# PayoutImporter). If credentials are missing, this initializer still
# loads fine — StripeClient.configured? returns false and
# PayoutImporter(:stripe_api) raises a friendly error.
#
# Phase 2/3 (UI button + name lock) keeps this pin unchanged.
Rails.application.config.after_initialize do
  Stripe.api_version = "2024-06-20"
end
