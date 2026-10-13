class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :payouts, dependent: :destroy
  has_many :transactions, dependent: :destroy

  # Per-user Stripe API credentials — encrypted at rest via Rails 7+
  # Active Record encryption. Each user owns their own Stripe
  # connection (regardless of who's paying Stripe, the key is per
  # account for the multi-tenant future). Storage class is
  # determined by Rails based on the keying config in
  # config/initializers/active_record_encryption.rb + credentials.
  #
  # `deterministic: false` (default) — keys are not queried by value,
  # only by `User#id`, so we don't need deterministic encryption.
  encrypts :stripe_secret_key

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }

  # True iff this user has stored a Stripe API key they can fetch
  # payouts with. The :stripe_api branch of PayoutImporter uses
  # this as its gate before hitting the Stripe API.
  def stripe_configured?
    stripe_secret_key.present?
  end
end
