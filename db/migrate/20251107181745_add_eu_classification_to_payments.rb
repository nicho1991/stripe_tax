class AddEuClassificationToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :eu_classification, :integer, default: 0, null: false
  end
end
