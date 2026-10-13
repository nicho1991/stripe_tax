class AddArrivalDateToPayouts < ActiveRecord::Migration[8.0]
  def change
    # Phase 1 of docs/stripe-direct-import-proposal.md. Stripe API
    # import path writes arrival_date from `Stripe::Payout#arrival_date`
    # at create time; CSV path will write it from a new form input in
    # Phase 3. Additive + nullable: existing Payout rows leave
    # arrival_date NULL on purpose (per owner direction "no rename of
    # things!"). Show page renders "(no date)" for NULLs.
    add_column :payouts, :arrival_date, :date, null: true

    # Composite index used by Phase 2's "Fetch from Stripe" picker
    # (window-by-arrival-date discovery) and Phase 4's payout.paid
    # webhook handler.
    add_index :payouts, [ :user_id, :arrival_date ]
  end
end
