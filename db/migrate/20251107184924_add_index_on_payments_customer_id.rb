class AddIndexOnPaymentsCustomerId < ActiveRecord::Migration[8.0]
  def change
    add_index :payments, :customer_id, where: 'customer_id IS NOT NULL'
  end
end
