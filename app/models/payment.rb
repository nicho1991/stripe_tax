class Payment < ApplicationRecord
  # Disable Single Table Inheritance since we use 'type' for payment type (Charge, Stripe Fee, etc.)
  self.inheritance_column = nil

  belongs_to :payout

  validates :type, presence: true
  validates :stripe_id, presence: true, uniqueness: { scope: :payout_id }
  validates :created_at_stripe, presence: true
  validates :amount, presence: true
  validates :converted_amount, presence: true
  validates :fees, presence: true
  validates :net, presence: true
end

