require "test_helper"

class StripePayoutFetcherTest < ActiveSupport::TestCase
  # Lightweight stubs for the modern stripe-ruby SDK chain
  # (`StripeClient.client.v1.payouts.list(...)` and
  # `StripeClient.client.v1.balance_transactions.list(...).auto_paging_each`).
  # Avoids needing webmock or a StripeMock Docker container.
  FakePayout = Struct.new(:id, :arrival_date, keyword_init: true)
  FakeBT = Struct.new(
    :id, :type, :amount, :fee, :net, :currency, :created,
    :description, :reporting_category, :source,
    keyword_init: true
  )

  class FakeList
    attr_reader :calls
    def initialize(data)
      @data = data
      @calls = []
    end

    def list(**kwargs)
      @calls << kwargs
      self
    end

    def data
      @data
    end
  end

  class FakeAutoPaging
    attr_reader :calls
    def initialize(data)
      @data = data
      @calls = []
    end

    def list(**kwargs)
      @calls << kwargs
      self
    end

    def auto_paging_each
      @data.each { |x| yield x }
      self
    end
  end

  def stub_client(payouts:, balance_transactions:)
    payouts_list = FakeList.new(payouts)
    bts_list = FakeAutoPaging.new(balance_transactions)

    # The fetcher calls StripeClient.client.v1.payouts.list(...) — so
    # we build a fake client whose .v1 chain exposes the resources.
    v1 = Object.new
    v1.define_singleton_method(:payouts) { payouts_list }
    v1.define_singleton_method(:balance_transactions) { bts_list }

    fake_client = Object.new
    fake_client.define_singleton_method(:v1) { v1 }

    original_client = StripeClient.method(:client)
    original_configured = StripeClient.method(:configured?)
    StripeClient.define_singleton_method(:client) { |**| fake_client }
    StripeClient.define_singleton_method(:configured?) { |**| true }
    yield payouts_list, bts_list
  ensure
    StripeClient.define_singleton_method(:client, original_client)
    StripeClient.define_singleton_method(:configured?, original_configured)
  end

  test "call returns empty result when no payouts in the window" do
    stub_client(payouts: [], balance_transactions: []) do |_payouts_list, _bts_list|
      result = StripePayoutFetcher.call(
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31), key: "sk_test_stub"
      )

      assert result.empty?
      assert_nil result.arrival_date
      assert_nil result.stripe_payout_id
    end
  end

  test "call discovers the payout by arrival_date window" do
    payout = FakePayout.new(
      id: "po_001",
      arrival_date: Time.utc(2026, 7, 1, 12, 0).to_i
    )

    stub_client(payouts: [ payout ], balance_transactions: []) do |payouts_list, _bts_list|
      StripePayoutFetcher.call(
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31), key: "sk_test_stub"
      )

      assert_equal 1, payouts_list.calls.size
      kwargs = payouts_list.calls.first
      assert_equal "paid", kwargs[:status]
      assert_equal 100, kwargs[:limit]
      assert kwargs[:arrival_date][:gte].is_a?(Integer)
      assert kwargs[:arrival_date][:lte].is_a?(Integer)
      assert kwargs[:arrival_date][:gte] >= Date.new(2026, 7, 1).beginning_of_day.to_i
      assert kwargs[:arrival_date][:lte] <= Date.new(2026, 7, 31).end_of_day.to_i
    end
  end

  test "call returns arrival_date as a Date in the app's time zone" do
    payout = FakePayout.new(
      id: "po_002",
      arrival_date: Time.utc(2026, 7, 1, 22, 30).to_i
    )

    stub_client(payouts: [ payout ], balance_transactions: []) do |_payouts_list, _bts_list|
      result = StripePayoutFetcher.call(
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31), key: "sk_test_stub"
      )

      assert_equal "po_002", result.stripe_payout_id
      assert_equal Date.new(2026, 7, 1), result.arrival_date
    end
  end

  test "call expands balance_transactions with data.source" do
    payout = FakePayout.new(id: "po_003", arrival_date: Time.utc(2026, 7, 1).to_i)
    bt = FakeBT.new(
      id: "txn_1",
      type: "charge",
      amount: 1000,
      fee: 0,
      net: 1000,
      currency: "usd",
      created: Time.utc(2026, 5, 27).to_i,
      description: "Test charge",
      reporting_category: "charge",
      source: Struct.new(:id).new("ch_001")
    )

    stub_client(payouts: [ payout ], balance_transactions: [ bt ]) do |_payouts_list, bts_list|
      result = StripePayoutFetcher.call(
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31), key: "sk_test_stub"
      )

      assert_equal 1, bts_list.calls.size
      assert_equal "po_003", bts_list.calls.first[:payout]
      assert_equal [ "data.source" ], bts_list.calls.first[:expand]
      assert_equal 100, bts_list.calls.first[:limit]

      assert_equal 1, result.rows.size
      assert_equal "Charge", result.rows.first[:type]
      assert_equal "ch_001", result.rows.first[:stripe_id]
      assert_equal 10.0.to_d, result.rows.first[:amount]
    end
  end

  test "call computes period_start and period_end from BT created timestamps" do
    payout = FakePayout.new(id: "po_004", arrival_date: Time.utc(2026, 7, 1).to_i)
    bts = [
      FakeBT.new(
        id: "txn_a", type: "charge", amount: 1000, fee: 0, net: 1000,
        currency: "usd", created: Time.utc(2026, 5, 27).to_i,
        description: nil, reporting_category: "charge",
        source: Struct.new(:id).new("ch_a")
      ),
      FakeBT.new(
        id: "txn_b", type: "charge", amount: 2000, fee: 0, net: 2000,
        currency: "usd", created: Time.utc(2026, 4, 29).to_i,
        description: nil, reporting_category: "charge",
        source: Struct.new(:id).new("ch_b")
      )
    ]

    stub_client(payouts: [ payout ], balance_transactions: bts) do |_payouts_list, _bts_list|
      result = StripePayoutFetcher.call(
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31), key: "sk_test_stub"
      )

      assert_equal Date.new(2026, 4, 29), result.period_start
      assert_equal Date.new(2026, 5, 27), result.period_end
    end
  end

  test "call wraps Stripe errors in FetchError" do
    flaky_v1 = Object.new
    flaky_v1.define_singleton_method(:payouts) do
      o = Object.new
      o.define_singleton_method(:list) { |**| raise Stripe::AuthenticationError.new("bad key") }
      o
    end
    flaky_v1.define_singleton_method(:balance_transactions) do
      o = Object.new
      o.define_singleton_method(:list) { |**| [] }
      o
    end

    flaky_client = Object.new
    flaky_client.define_singleton_method(:v1) { flaky_v1 }

    original_client = StripeClient.method(:client)
    original_configured = StripeClient.method(:configured?)
    StripeClient.define_singleton_method(:client) { |**| flaky_client }
    StripeClient.define_singleton_method(:configured?) { |**| true }

    err = assert_raises(StripePayoutFetcher::FetchError) do
      StripePayoutFetcher.call(
        start_date: Date.new(2026, 7, 1),
        end_date: Date.new(2026, 7, 31), key: "sk_test_stub"
      )
    end
    assert_match(/Stripe API error/, err.message)
  ensure
    StripeClient.define_singleton_method(:client, original_client)
    StripeClient.define_singleton_method(:configured?, original_configured)
  end
end
