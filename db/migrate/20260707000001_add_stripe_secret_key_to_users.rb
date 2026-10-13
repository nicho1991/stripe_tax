class AddStripeSecretKeyToUsers < ActiveRecord::Migration[8.0]
  def change
    # Add the encrypted column backing User#stripe_secret_key. Rails
    # 7+ `encrypts` writes ciphertext to a column of the same name.
    # `deterministic: false` is the default — API keys are not
    # queried by value, only by `User#id`, so we don't need
    # deterministic encryption (which would allow equality lookup).
    add_column :users, :stripe_secret_key, :string
  end
end
