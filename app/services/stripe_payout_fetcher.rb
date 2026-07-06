# Fetch the rows for one Stripe payout window via the modern stripe-ruby
# SDK. Returns a hash:
#   {
#     arrival_date: Date,
#     stripe_payout_id: "po_...",
#     rows: [ { type:, stripe_id:, ... }, ... ]
#   }
#
# `rows` is the same shape PayoutCsvParser produces per row, so
# PayoutImporter can reuse the existing Payment-row creation path
# without reshaping the parser.
#
# Window discovery uses `arrival_date` on Stripe::Payout (matches the
# Stripe dashboard "Payouts" view). Activity-window min/max for the
# period_start/period_end fields is computed from the BT rows' `created`
# timestamps — same semantics the CSV path already produces.
#
# Modern SDK style only (stripe-ruby 19.x). NO legacy
# `Stripe::BalanceTransaction.list` / `Stripe::Payout.list` calls —
# everything goes through the memoized `StripeClient.client.v1.*`.
class StripePayoutFetcher
  class FetchError < StandardError; end

  Result = Struct.new(:arrival_date, :stripe_payout_id, :rows, keyword_init: true) do
    def empty?
      rows.empty?
    end

    def period_start
      rows.map { |r| r[:created_at_stripe].to_date }.min
    end

    def period_end
      rows.map { |r| r[:created_at_stripe].to_date }.max
    end
  end

  def self.call(start_date:, end_date:)
    new(start_date, end_date).call
  end

  def initialize(start_date, end_date)
    @start_date = start_date
    @end_date = end_date
  end

  def call
    payout = discover_payout
    return Result.new(arrival_date: nil, stripe_payout_id: nil, rows: []) if payout.nil?

    rows = balance_transaction_rows(payout)
    Result.new(
      arrival_date: arrival_date_for(payout),
      stripe_payout_id: payout.id,
      rows: rows
    )
  rescue Stripe::StripeError => e
    raise FetchError, "Stripe API error: #{e.message}"
  end

  private

  def discover_payout
    gte = @start_date.beginning_of_day.to_i
    lte = @end_date.end_of_day.to_i

    payouts = StripeClient.client.v1.payouts.list(
      status: "paid",
      arrival_date: { gte: gte, lte: lte },
      limit: 100
    )

    payouts.data.first
  end

  def balance_transaction_rows(payout)
    rows = []
    StripeClient.client.v1.balance_transactions.list(
      payout: payout.id,
      limit: 100,
      expand: [ "data.source" ]
    ).auto_paging_each do |bt|
      rows << StripePayoutBuilder.row_for(bt)
    end
    rows
  end

  def arrival_date_for(payout)
    return nil if payout.arrival_date.nil?

    Time.zone.at(payout.arrival_date).to_date
  end
end
