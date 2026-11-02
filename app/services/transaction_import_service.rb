class TransactionImportService
  attr_reader :user, :errors, :warnings

  def initialize(user)
    @user = user
    @errors = []
    @warnings = []
  end

  def import(transactions_data)
    imported_count = 0
    updated_count = 0
    skipped_count = 0

    transactions_data.each do |transaction_data|
      transaction_id = transaction_data[:transaction_id]
      existing_transaction = user.transactions.find_by(transaction_id: transaction_id)

      if existing_transaction
        if transaction_data_matches?(existing_transaction, transaction_data)
          skipped_count += 1
        else
          if update_transaction(existing_transaction, transaction_data)
            updated_count += 1
            update_linked_payment_classification(existing_transaction)
          else
            errors << "Failed to update transaction #{transaction_id}: #{existing_transaction.errors.full_messages.join(', ')}"
          end
        end
      else
        transaction = create_transaction(transaction_data)
        if transaction.persisted?
          imported_count += 1
          update_linked_payment_classification(transaction)
        else
          errors << "Failed to import transaction #{transaction_id}: #{transaction.errors.full_messages.join(', ')}"
        end
      end
    end

    {
      imported: imported_count,
      updated: updated_count,
      skipped: skipped_count,
      warnings: warnings,
      errors: errors
    }
  end

  private

  def create_transaction(transaction_data)
    transaction = user.transactions.build(transaction_attributes(transaction_data))

    update_derived_attributes(transaction)
    transaction.save
    transaction
  end

  def update_transaction(transaction, transaction_data)
    transaction.assign_attributes(transaction_attributes(transaction_data))
    update_derived_attributes(transaction)
    transaction.save
  end

  def transaction_data_matches?(transaction, transaction_data)
    transaction_attributes(transaction_data).all? do |field, new_value|
      next true if field == :transaction_id

      existing_value = transaction.public_send(field)
      normalize_value(existing_value) == normalize_value(new_value)
    end
  end

  def transaction_attributes(transaction_data)
    transaction_data.slice(
      :transaction_id, :created_at_stripe, :status, :decline_reason,
      :card_address_country, :card_issue_country, :shipping_address_country, :raw_data
    )
  end

  def normalize_value(value)
    value.is_a?(String) ? value.strip.presence : value
  end

  def update_derived_attributes(transaction)
    transaction.location_confidence_score = transaction.calculate_location_confidence_score
    transaction.eu_classification = EuClassificationService.classify_transaction(transaction)
  end

  def update_linked_payment_classification(transaction)
    payment = Payment.joins(:payout)
                     .where(payouts: { user_id: user.id })
                     .find_by(stripe_id: transaction.transaction_id)
    return unless payment

    payment.update(eu_classification: transaction.eu_classification)
  end
end
