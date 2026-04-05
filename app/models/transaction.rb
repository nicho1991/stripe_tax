class Transaction < ApplicationRecord
  belongs_to :user
  has_one :payment, foreign_key: :stripe_id, primary_key: :transaction_id

  enum :eu_classification, { undetermined: 0, eu: 1, non_eu: 2, stripe_fees: 3 }

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

  # Find all transactions for the same customer (via payment.customer_id)
  def customer_transactions
    return Transaction.none unless payment&.customer_id.present?

    customer_id = payment.customer_id
    Transaction.joins('INNER JOIN payments ON transactions.transaction_id = payments.stripe_id')
               .joins('INNER JOIN payouts ON payments.payout_id = payouts.id')
               .where(payments: { customer_id: customer_id })
               .where(payouts: { user_id: user_id })
               .where.not(id: id)
  end

  # Enhanced location confidence using other customer transactions (read-only)
  def enhanced_location_confidence
    other_transactions = customer_transactions
    return {
      enhanced_score: location_confidence_score,
      inferred_fields: [],
      inferred_data: {}
    } if other_transactions.empty?

    inferred_data = {}
    inferred_fields = []

    # Infer missing fields from other customer transactions
    [:card_address_country, :card_issue_country, :shipping_address_country].each do |field|
      next if send(field).present? # Skip if field already has a value

      # Find most common non-nil value across other customer transactions
      values = other_transactions.map { |t| t.send(field) }.compact
      next if values.empty?

      # Get most common value
      most_common = values.group_by(&:itself).max_by { |_, v| v.length }&.first
      if most_common.present?
        inferred_data[field] = most_common
        inferred_fields << field.to_s
      end
    end

    # Calculate enhanced confidence score
    enhanced_score = location_confidence_score + inferred_fields.length

    {
      enhanced_score: [enhanced_score, 3].min, # Cap at 3
      inferred_fields: inferred_fields,
      inferred_data: inferred_data
    }
  end

  # Customer-influenced EU classification (read-only)
  def customer_influenced_eu_classification
    enhancement = enhanced_location_confidence
    return {
      original: eu_classification,
      customer_influenced: eu_classification
    } if enhancement[:inferred_fields].empty?

    # Create a virtual transaction with enhanced location data
    # Use a simple struct-like object that responds to the methods needed
    virtual_transaction = Struct.new(:card_address_country, :card_issue_country, :shipping_address_country).new(
      card_address_country || enhancement[:inferred_data][:card_address_country],
      card_issue_country || enhancement[:inferred_data][:card_issue_country],
      shipping_address_country || enhancement[:inferred_data][:shipping_address_country]
    )

    customer_influenced = EuClassificationService.classify_transaction(virtual_transaction)

    {
      original: eu_classification,
      customer_influenced: customer_influenced
    }
  end
end

