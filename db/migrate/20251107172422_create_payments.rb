class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :payout, null: false, foreign_key: true
      t.string :type, null: false
      t.string :stripe_id, null: false
      t.datetime :created_at_stripe, null: false
      t.text :description
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency
      t.decimal :converted_amount, precision: 10, scale: 2
      t.decimal :fees, precision: 10, scale: 2
      t.decimal :net, precision: 10, scale: 2
      t.string :converted_currency
      t.text :details
      t.string :customer_id
      t.string :customer_email
      t.string :customer_name

      t.timestamps
    end

    add_index :payments, :stripe_id
    add_index :payments, [ :payout_id, :stripe_id ], unique: true
  end
end
