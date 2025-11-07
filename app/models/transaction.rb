class Transaction < ApplicationRecord
  belongs_to :user
  has_one :payment, foreign_key: :stripe_id, primary_key: :transaction_id

  enum :eu_classification, { undetermined: 0, eu: 1, non_eu: 2 }

  validates :transaction_id, presence: true, uniqueness: true
  validates :created_at_stripe, presence: true

  scope :successful, -> { where(status: 'Paid') }

  def calculate_location_confidence_score
    score = 0
    score += 1 if card_address_country.present?
    score += 1 if card_issue_country.present?
    score += 1 if shipping_address_country.present?
    score
  end
end

