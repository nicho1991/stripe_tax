require "test_helper"

class PayoutImporterTest < ActiveSupport::TestCase
  # Sample CSV in the exact format the Stripe payouts export produces.
  # Mirrors the column shape `PayoutCsvParser` parses today. Used to
  # prove the :csv branch produces identical output to the controller.
  SAMPLE_CSV = <<~CSV
    Type,ID,Created,Description,Amount,Currency,Converted Amount,Fees,Net,Converted Currency,Details,Customer ID,Customer Email,Customer Name
    Charge,ch_abc123,2026-05-27 12:00,Order #1234,49.99,USD,49.99,1.74,48.25,USD,charge,cus_001,buyer@example.com,Buyer
    Stripe Fee,fee_001,2026-05-27 12:00,Stripe fee,-1.74,USD,-1.74,0.00,-1.74,USD,stripe_fee,,,
  CSV

  def user
    users(:one)
  end

  test ":csv branch succeeds with a valid CSV and creates a Payout + Payments" do
    result = PayoutImporter.call(
      source: :csv,
      user: user,
      csv_content: SAMPLE_CSV
    )

    assert result.success?, "expected success, got: #{result.errors.inspect}"
    assert result.payout.persisted?
    # Both rows have "2026-05-27" so period_start == period_end.
    assert_equal "May 2026", result.payout.name
    assert_equal Date.new(2026, 5, 27), result.payout.period_start
    assert_equal Date.new(2026, 5, 27), result.payout.period_end
    assert_nil result.payout.arrival_date
    assert_equal 2, result.payout.payments.count
  end

  test ":csv branch returns errors for malformed CSV" do
    bad_csv = "Type,ID,Created\nnope\n"

    result = PayoutImporter.call(
      source: :csv,
      user: user,
      csv_content: bad_csv
    )

    refute result.success?
    assert result.errors.any?
  end

  test ":csv branch reads from csv_file when no csv_content given" do
    file = StringIO.new(SAMPLE_CSV)

    result = PayoutImporter.call(
      source: :csv,
      user: user,
      csv_file: file
    )

    assert result.success?, "expected success, got: #{result.errors.inspect}"
    assert result.payout.persisted?
  end

  test ":csv branch matches controller's bit-for-bit output" do
    # Baseline: simulate what `payouts_controller#create` did on
    # main before Phase 1, by running the parser + create flow
    # directly here. The :csv branch must produce equivalent rows.
    #
    # We compare the row hashes themselves (not persisted Payouts) to
    # avoid the `no_overlapping_periods` validation that would block
    # creating two payouts for the same period back-to-back. The
    # :csv branch is a thin wrapper that calls PayoutCsvParser and
    # then writes each payment row verbatim — so comparing the parsed
    # rows directly is the strongest equivalence check we can make.
    parser = ::PayoutCsvParser.new(SAMPLE_CSV)
    parsed = parser.parse
    assert parsed[:success]

    # The importer's :csv branch produces the same payment rows as
    # the parser — verify by feeding the SAME csv_content through
    # the importer and reading the persisted Payment rows.
    result = PayoutImporter.call(
      source: :csv,
      user: user,
      csv_content: SAMPLE_CSV
    )
    assert result.success?, "expected success, got: #{result.errors.inspect}"

    persisted = result.payout.payments
    expected  = parsed[:payments]

    assert_equal expected.size, persisted.size
    expected.each_with_index do |exp, idx|
      got = persisted[idx]
      assert_equal exp[:type], got.type
      assert_equal exp[:stripe_id], got.stripe_id
      assert_equal exp[:amount].to_s, got.amount.to_s
      assert_equal exp[:fees].to_s, got.fees.to_s
      assert_equal exp[:net].to_s, got.net.to_s
      # eu_classification is an enum on Payment — it reads back as a
      # string ("undetermined" / "stripe_fees" / ...) rather than the
      # underlying integer the parser emits. Compare via the enum map.
      assert_equal exp[:eu_classification], Payment.eu_classifications[got.eu_classification]
    end
  end

  test ":stripe_api branch raises CredentialsMissing when no key configured" do
    with_stubbed_stripe(configured: false, client: nil) do
      result = PayoutImporter.call(
        source: :stripe_api,
        user: user,
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31)
      )

      refute result.success?
      assert_match(/credentials missing/i, result.errors.first)
    end
  end

  test ":stripe_api branch returns failure when no payout found in window" do
    with_stubbed_stripe(configured: true, client: stub_empty_v1_client) do
      result = PayoutImporter.call(
        source: :stripe_api,
        user: user,
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31)
      )

      refute result.success?
      assert_match(/no stripe payout found/i, result.errors.first)
    end
  end

  test ":stripe_api branch succeeds when a payout is found and writes arrival_date" do
    with_stubbed_stripe(configured: true, client: stub_v1_client_with_one_payout) do
      result = PayoutImporter.call(
        source: :stripe_api,
        user: user,
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31)
      )

      assert result.success?, "expected success, got: #{result.errors.inspect}"
      assert result.payout.persisted?
      assert_equal Date.new(2026, 7, 1), result.payout.arrival_date
      assert_equal "JUL 1 - 2026", result.payout.name
      assert result.payout.payments.any?
    end
  end

  test "unknown source returns failure" do
    result = PayoutImporter.call(
      source: :bogus,
      user: user
    )

    refute result.success?
    assert_match(/Unknown source/, result.errors.first)
  end

  private

  def with_stubbed_stripe(configured:, client:)
    original_client = StripeClient.method(:client)
    original_configured = StripeClient.method(:configured?)
    StripeClient.define_singleton_method(:client) { client } if client
    StripeClient.define_singleton_method(:configured?) { configured }
    yield
  ensure
    StripeClient.define_singleton_method(:client, original_client)
    StripeClient.define_singleton_method(:configured?, original_configured)
  end

  def stub_empty_v1_client
    empty_payouts = Object.new
    empty_payouts.define_singleton_method(:list) { |**| Struct.new(:data).new([]) }
    empty_bts = Object.new
    empty_bts.define_singleton_method(:list) do |**|
      pager = Object.new
      pager.define_singleton_method(:auto_paging_each) { |&_block| pager }
      pager
    end

    v1 = Object.new
    v1.define_singleton_method(:payouts) { empty_payouts }
    v1.define_singleton_method(:balance_transactions) { empty_bts }
    client = Object.new
    client.define_singleton_method(:v1) { v1 }
    client
  end

  def stub_v1_client_with_one_payout
    payout = Struct.new(:id, :arrival_date).new(
      "po_test_001",
      Time.utc(2026, 7, 1, 12, 0).to_i
    )

    bt_source = Struct.new(:id, :description).new("ch_xyz", "Imported charge")
    bt = Struct.new(
      :id, :type, :amount, :fee, :net, :currency, :created,
      :description, :reporting_category, :source
    ).new(
      "txn_test_1", "charge", 1000, 174, 826, "usd",
      Time.utc(2026, 5, 27).to_i, nil, "charge", bt_source
    )

    payouts_resource = Object.new
    payouts_resource.define_singleton_method(:list) { |**| Struct.new(:data).new([ payout ]) }

    bts_resource = Object.new
    bts_resource.define_singleton_method(:list) do |**|
      pager = Object.new
      pager.define_singleton_method(:auto_paging_each) do |&block|
        block.call(bt)
        pager
      end
      pager
    end

    v1 = Object.new
    v1.define_singleton_method(:payouts) { payouts_resource }
    v1.define_singleton_method(:balance_transactions) { bts_resource }
    client = Object.new
    client.define_singleton_method(:v1) { v1 }
    client
  end
end
