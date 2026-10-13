class AddStripeFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :stripe_api_key, :text
    add_column :users, :stripe_api_key_last4, :string
    add_column :users, :stripe_api_key_prefix, :string
    add_column :users, :stripe_account_id, :string
    add_column :users, :stripe_account_label, :string
    add_column :users, :stripe_account_country, :string
    add_column :users, :stripe_account_default_currency, :string
    add_column :users, :stripe_connected_at, :datetime
  end
end
