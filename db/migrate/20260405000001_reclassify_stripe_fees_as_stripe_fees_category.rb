class ReclassifyStripeFeesAsStripeFeesCategory < ActiveRecord::Migration[8.0]
  def change
    # Update existing Stripe Fee payments from undetermined (0) to stripe_fees (3)
    Payment.where(type: "Stripe Fee", eu_classification: 0).update_all(eu_classification: 3)
  end
end
