class RecalculateEuClassifications < ActiveRecord::Migration[8.0]
  def up
    say "Recalculating EU classifications for all transactions and payments..."

    updated_transactions = 0
    updated_payments = 0

    # Process transactions in batches for memory efficiency
    Transaction.find_each do |transaction|
      # Recalculate classification using the updated service logic
      new_classification_symbol = EuClassificationService.classify_transaction(transaction)

      # Convert symbol to integer enum value
      # enum values: { "undetermined" => 0, "eu" => 1, "non_eu" => 2 }
      new_classification_int = Transaction.eu_classifications[new_classification_symbol.to_s]

      # Only update if classification has changed
      if transaction.eu_classification != new_classification_int
        transaction.update_column(:eu_classification, new_classification_int)
        updated_transactions += 1

        # Update linked payment(s) to match
        # Payments are linked via stripe_id = transaction_id
        Payment.where(stripe_id: transaction.transaction_id).find_each do |payment|
          payment.update_column(:eu_classification, new_classification_int)
          updated_payments += 1
        end
      end
    end

    say "Updated #{updated_transactions} transactions and #{updated_payments} payments", true
  end

  def down
    say "This migration cannot be reversed. EU classifications have been recalculated.", true
    raise ActiveRecord::IrreversibleMigration
  end
end
