class TransactionImportService
  attr_reader :user, :errors, :warnings

  def initialize(user)
    @user = user
    @errors = []
    @warnings = []
  end

  def import(transactions_data)
    imported_count = 0
    skipped_count = 0

    transactions_data.each do |transaction_data|
      transaction_id = transaction_data[:transaction_id]
      existing_transaction = user.transactions.find_by(transaction_id: transaction_id)

      if existing_transaction
        differences = compare_transactions(existing_transaction, transaction_data)
        if differences.empty?
          skipped_count += 1
        else
          warnings << "Transaction #{transaction_id} differs: #{differences.join(', ')}"
          skipped_count += 1
        end
      else
        # Create new transaction
        transaction = create_transaction(transaction_data)
        if transaction.persisted?
          imported_count += 1
          # Update linked payment's EU classification if payment exists
          update_linked_payment_classification(transaction)
        else
          errors << "Failed to import transaction #{transaction_id}: #{transaction.errors.full_messages.join(', ')}"
        end
      end
    end

    {
      imported: imported_count,
      skipped: skipped_count,
      warnings: warnings,
      errors: errors
    }
  end

  private

  def create_transaction(transaction_data)
    transaction = user.transactions.build(
      transaction_id: transaction_data[:transaction_id],
      created_at_stripe: transaction_data[:created_at_stripe],
      status: transaction_data[:status],
      decline_reason: transaction_data[:decline_reason],
      card_address_country: transaction_data[:card_address_country],
      card_issue_country: transaction_data[:card_issue_country],
      shipping_address_country: transaction_data[:shipping_address_country],
      raw_data: transaction_data[:raw_data]
    )

    # Calculate confidence score
    transaction.location_confidence_score = transaction.calculate_location_confidence_score

    # Classify EU status
    classification = EuClassificationService.classify_transaction(transaction)
    transaction.eu_classification = classification

    transaction.save
    transaction
  end

  def compare_transactions(existing, new_data)
    differences = []
    fields_to_compare = [
      :created_at_stripe, :status, :decline_reason,
      :card_address_country, :card_issue_country, :shipping_address_country
    ]

    fields_to_compare.each do |field|
      existing_value = existing.send(field)
      new_value = new_data[field]

      # Normalize for comparison (handle nil/blank)
      existing_value = existing_value.to_s.strip if existing_value
      new_value = new_value.to_s.strip if new_value

      if existing_value != new_value
        differences << "#{field} changed from '#{existing_value || 'nil'}' to '#{new_value || 'nil'}'"
      end
    end

    differences
  end

  def update_linked_payment_classification(transaction)
    # Find payment across all payouts for this user
    payment = Payment.joins(:payout)
                     .where(payouts: { user_id: user.id })
                     .find_by(stripe_id: transaction.transaction_id)
    return unless payment

    # Update payment's EU classification to match transaction
    payment.update(eu_classification: transaction.eu_classification)
  end
end
