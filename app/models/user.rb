class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :payouts, dependent: :destroy
  has_many :transactions, dependent: :destroy

  # Encrypted at rest via Active Record encryption.
  # We never expose this to the API surface; only StripeConnectionService reads it.
  encrypts :stripe_api_key

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }

  # Restricted keys are Stripe's recommended lowest-risk option for API integrations.
  # They look like: rk_test_... (test mode) or rk_live_... (live mode).
  STRIPE_RESTRICTED_KEY_REGEX = /\Ark_(test|live)_[A-Za-z0-9]+\z/
  STRIPE_KEY_PREFIX_REGEX = /\Ark_(test|live)_/

  validate :stripe_api_key_format, if: :stripe_api_key_changed?

  def stripe_connected?
    stripe_api_key.present?
  end

  def stripe_account_verified?
    stripe_connected? && stripe_account_id.present?
  end

  def stripe_masked_key
    return nil if stripe_api_key.blank?
    "#{stripe_api_key_prefix}...#{stripe_api_key_last4}"
  end

  def clear_stripe_connection!
    update!(
      stripe_api_key: nil,
      stripe_api_key_last4: nil,
      stripe_api_key_prefix: nil,
      stripe_account_id: nil,
      stripe_account_label: nil,
      stripe_account_country: nil,
      stripe_account_default_currency: nil,
      stripe_connected_at: nil
    )
  end

  private

  def stripe_api_key_format
    return if stripe_api_key.blank?

    unless stripe_api_key.match?(STRIPE_RESTRICTED_KEY_REGEX)
      errors.add(:stripe_api_key, "must be a Stripe restricted key starting with rk_test_ or rk_live_")
    end
  end
end
