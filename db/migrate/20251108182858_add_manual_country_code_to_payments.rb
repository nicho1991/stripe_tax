class AddManualCountryCodeToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :manual_country_code, :string
    add_index :payments, :manual_country_code
  end
end
