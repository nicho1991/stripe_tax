# Convert a Stripe balance_transaction row + its expanded source into
# the same row shape `PayoutCsvParser` produces for CSV rows. This is
# what lets `PayoutImporter` reuse the same Payment-row creation path
# for both `:csv` and `:stripe_api` branches without reshaping the
# existing parser.
#
# Sign convention (per owner direction §6): Stripe's `bt.amount`,
# `bt.net`, and `bt.fee` are pushed through unchanged. Charges end
# up positive, refunds negative, fees negative — exactly mirroring
# what the Stripe payout CSV shows today. No normalization.
#
# The mapper covers the types `bt.type` returns that the CSV's
# `Type` column uses. If Stripe adds new types we don't know about,
# the caller's `.compact_blank` on the resulting hash will let the
# downstream `payments.create!` raise a clear validation error.
class StripePayoutBuilder
  # Map Stripe::BalanceTransaction.type values to the human-readable
  # labels the existing PayoutCsvParser writes into `payments.type`.
  # Keys are lowercased to match what Stripe's SDK returns.
  TYPE_LABELS = {
    "charge"            => "Charge",
    "payment"           => "Charge",
    "refund"            => "Refund",
    "payment_refund"    => "Refund",
    "stripe_fee"        => "Stripe Fee",
    "application_fee"   => "Stripe Fee",
    "dispute"           => "Dispute",
    "issuing_dispute"   => "Dispute",
    "adjustment"        => "Adjustment",
    "network_cost"      => "Stripe Fee"
  }.freeze

  # Build the Payout name from the Stripe payout's arrival_date.
  # Wraps PayoutName.from so callers don't have to know which helper
  # to use.
  def self.build_name(arrival_date)
    PayoutName.from(arrival_date)
  end

  # bt is a Stripe::BalanceTransaction (with `expand: ["data.source"]`
  # applied at fetch time so `bt.source` is the expanded object, not
  # just an id string). Returns a hash that matches the row shape
  # `PayoutCsvParser#parse_payment_row` produces.
  def self.row_for(bt)
    source = bt.respond_to?(:source) ? bt.source : nil
    customer = extract_customer(source)

    {
      type: TYPE_LABELS[bt.type.to_s.downcase] || bt.type.to_s.titleize,
      stripe_id: source_id(bt, source),
      created_at_stripe: Time.zone.at(bt.created),
      description: source_description(bt, source),
      amount: major_units(bt.amount),
      currency: bt.currency&.upcase,
      converted_amount: major_units(bt.amount),
      fees: major_units(fees_minor(bt)),
      net: major_units(bt.net),
      converted_currency: bt.currency&.upcase,
      details: bt.reporting_category || bt.type,
      customer_id: customer&.id,
      customer_email: customer&.email,
      customer_name: customer&.name,
      eu_classification: bt.type.to_s.downcase.include?("fee") ? 3 : 0
    }
  end

  def self.source_id(bt, source)
    # PayoutCsvParser stores the SOURCE object id (ch_…, re_…, dp_…,
    # fee_…), not the txn_… balance_transaction id. With
    # expand: ["data.source"] we have the source object directly.
    if source.respond_to?(:id)
      source.id
    else
      # Fall back to the BT id when no expansion (rare; tests only).
      bt.id
    end
  end

  def self.source_description(bt, source)
    return bt.description if bt.description.present?

    if source.respond_to?(:description) && source.description.present?
      source.description
    elsif source.respond_to?(:reason)
      source.reason
    else
      bt.type.to_s.titleize
    end
  end

  # Convert Stripe's minor units (cents) to the major-unit BigDecimal
  # shape `PayoutCsvParser#parse_decimal` produces. Sign preserved —
  # charges stay positive, refunds stay negative, fees stay negative —
  # so the same row shape lands in `payments.*` for both `:csv` and
  # `:stripe_api` branches of `PayoutImporter`.
  def self.major_units(minor)
    return 0 if minor.nil?

    BigDecimal(minor.to_s) / 100
  end

  # The `fees` column mirrors what the Stripe payout CSV shows:
  # - On a Charge row, fees is positive (the fee Stripe charged).
  # - On a Stripe Fee row (a separate BT line item that accounts
  #   for the fee as a deduction), fees is negative (the deduction).
  # Stripe's `bt.fee` is always non-negative, but the BT row's
  # `amount` is negative for fee-only BTs — so we route by `type`.
  def self.fees_minor(bt)
    return bt.amount if bt.type.to_s.downcase.include?("fee")

    bt.fee
  end

  # Customer may be a string id, an expanded object, or nil. Return
  # the object form when expanded.
  def self.extract_customer(source)
    return nil unless source.respond_to?(:customer)

    customer = source.customer
    return nil if customer.nil? || customer.is_a?(String)

    customer
  end
end
