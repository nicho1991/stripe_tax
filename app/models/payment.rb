class Payment < ApplicationRecord
  # Disable Single Table Inheritance since we use 'type' for payment type (Charge, Stripe Fee, etc.)
  self.inheritance_column = nil

  belongs_to :payout
  has_one :stripe_transaction, class_name: 'Transaction', foreign_key: :transaction_id, primary_key: :stripe_id, dependent: :nullify

  enum :eu_classification, { undetermined: 0, eu: 1, non_eu: 2 }

  validates :type, presence: true
  validates :stripe_id, presence: true, uniqueness: { scope: :payout_id }
  validates :created_at_stripe, presence: true
  validates :amount, presence: true
  validates :converted_amount, presence: true
  validates :fees, presence: true
  validates :net, presence: true
end

