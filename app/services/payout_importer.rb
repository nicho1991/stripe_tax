# Orchestrator for creating a Payout (and its Payment rows) from
# either of two sources: a user-uploaded Stripe CSV (the existing
# path) or a direct Stripe API fetch (Phase 1's new path).
#
# Backwards-compatibility invariant: the `:csv` branch is
# BIT-FOR-BIT equivalent to what `payouts_controller#create` did on
# the same CSV content under main before Phase 1. Verified by the
# `:csv` branch test in `test/services/payout_importer_test.rb`
# running the same fixture content through both paths and asserting
# row-for-row equality.
#
# The `:stripe_api` branch is the new path. It uses
# `StripePayoutFetcher` to discover the payout and pull its balance
# transactions, then writes `arrival_date` from Stripe and
# `name = PayoutName.from(arrival_date)` per the proposal §3.
#
# This class is reachable only from `rails console` (and from the
# future Phase 2 controller action). `payouts_controller#create`
# remains unchanged in Phase 1 — Phase 3 will refactor it to call
# the :csv branch here.
class PayoutImporter
  class CredentialsMissing < StandardError; end

  Result = Struct.new(:success, :payout, :errors, :warnings, keyword_init: true) do
    alias_method :success?, :success
  end

  def self.call(source:, user:, csv_content: nil, csv_file: nil, start_date: nil, end_date: nil, arrival_date: nil)
    new(
      source: source,
      user: user,
      csv_content: csv_content,
      csv_file: csv_file,
      start_date: start_date,
      end_date: end_date,
      arrival_date: arrival_date
    ).call
  end

  def initialize(source:, user:, csv_content:, csv_file:, start_date:, end_date:, arrival_date:)
    @source = source
    @user = user
    @csv_content = csv_content
    @csv_file = csv_file
    @start_date = start_date
    @end_date = end_date
    @arrival_date = arrival_date
  end

  def call
    case @source
    when :csv then import_from_csv
    when :stripe_api then import_from_stripe_api
    else
      Result.new(success: false, errors: [ "Unknown source: #{@source.inspect}" ])
    end
  rescue CredentialsMissing => e
    Result.new(success: false, errors: [ e.message ])
  end

  private

  # CSV path — replicates payouts_controller#create's
  # parser + create flow bit-for-bit. The `arrival_date` kwarg is the
  # user-provided "Payout Date" date input from Phase 3's form; it
  # controls the displayed name (`PayoutName.from(arrival_date)`).
  # When omitted (e.g. a script-invoked import that doesn't care
  # about the displayed name), name falls back to the parser-derived
  # `period_name` to keep pre-Phase-3 callers working unchanged.
  def import_from_csv
    csv_text = read_csv_content
    return Result.new(success: false, errors: [ "CSV content is empty" ]) if csv_text.blank?

    parser = ::PayoutCsvParser.new(csv_text)
    parsed = parser.parse

    unless parsed[:success]
      return Result.new(success: false, errors: parsed[:errors])
    end

    payout_name = @arrival_date ? PayoutName.from(@arrival_date) : parsed[:period_name]

    payout = create_payout(
      name: payout_name,
      period_start: parsed[:period_start],
      period_end: parsed[:period_end],
      arrival_date: @arrival_date
    )

    return payout unless payout.is_a?(Payout)

    parsed[:payments].each { |row| payout.payments.create!(row) }
    Result.new(success: true, payout: payout, errors: [], warnings: [])
  end

  # Stripe API path — Phase 1's new feature. Adds the console smoke
  # step documented in docs/stripe-direct-import-proposal.md §4
  # Phase 1. Reachable from Phase 2 via `POST /payouts/fetch`.
  def import_from_stripe_api
    raise CredentialsMissing, "Stripe API credentials missing" unless StripeClient.configured?

    fetched = StripePayoutFetcher.call(start_date: @start_date, end_date: @end_date)

    if fetched.empty?
      return Result.new(
        success: false,
        errors: [ "No Stripe payout found between #{@start_date} and #{@end_date}" ]
      )
    end

    payout = create_payout(
      name: PayoutName.from(fetched.arrival_date),
      period_start: fetched.period_start,
      period_end: fetched.period_end,
      arrival_date: fetched.arrival_date
    )

    return payout unless payout.is_a?(Payout)

    fetched.rows.each { |row| payout.payments.create!(row) }
    Result.new(success: true, payout: payout, errors: [], warnings: [])
  end

  # Reads CSV from either an in-memory string or an uploaded file.
  # Forces UTF-8 encoding to match the existing controller behaviour.
  def read_csv_content
    if @csv_content.present?
      @csv_content.dup.force_encoding("UTF-8")
    elsif @csv_file.present?
      content = @csv_file.read.dup.force_encoding("UTF-8")
      @csv_file.rewind
      content
    end
  end

  # Creates the Payout row wrapped in a transaction. On validation
  # failure returns a Result so the caller (controller or console)
  # can render the error without rescuing.
  def create_payout(name:, period_start:, period_end:, arrival_date:)
    payout = nil
    ActiveRecord::Base.transaction do
      payout = @user.payouts.create!(
        name: name,
        period_start: period_start,
        period_end: period_end,
        arrival_date: arrival_date
      )
    end
    payout
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success: false, errors: e.record.errors.full_messages)
  end
end
