class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :transaction_id, null: false
      t.datetime :created_at_stripe, null: false
      t.string :status
      t.string :decline_reason
      t.string :card_address_country
      t.string :card_issue_country
      t.string :shipping_address_country
      t.integer :location_confidence_score, default: 0
      t.integer :eu_classification, default: 0, null: false
      t.jsonb :raw_data

      t.timestamps
    end

    add_index :transactions, :transaction_id, unique: true
    add_index :transactions, :eu_classification
  end
end
