require "test_helper"

class StripePayoutBuilderTest < ActiveSupport::TestCase
  # Build a minimal Stripe::BalanceTransaction-like struct for testing
  # the builder in isolation. Real Stripe objects are heavy to construct
  # in unit tests; the builder only touches a handful of fields.
  FakeSource = Struct.new(
    :id, :description, :reason, :customer,
    keyword_init: true
  ) do
    def respond_to_missing?(name, include_private = false)
      [ :description, :reason, :customer ].include?(name) || super
    end
  end

  FakeBT = Struct.new(
    :id, :type, :amount, :fee, :net, :currency, :created, :description,
    :reporting_category, :source,
    keyword_init: true
  )

  test "row_for charges positive in major units" do
    source = FakeSource.new(id: "ch_abc123")
    bt = FakeBT.new(
      id: "txn_1",
      type: "charge",
      amount: 4999,
      fee: 174,
      net: 4825,
      currency: "usd",
      created: Time.utc(2026, 5, 27, 12, 0).to_i,
      description: "Charge for order #1234",
      reporting_category: "charge",
      source: source
    )

    row = StripePayoutBuilder.row_for(bt)

    assert_equal "Charge", row[:type]
    assert_equal "ch_abc123", row[:stripe_id]  # source.id, NOT the BT id
    assert_equal 49.99.to_d, row[:amount]
    assert_equal 49.99.to_d, row[:converted_amount]
    assert_equal 1.74.to_d, row[:fees]
    assert_equal 48.25.to_d, row[:net]
    assert_equal "USD", row[:currency]
    assert_equal 0, row[:eu_classification]
  end

  test "row_for refunds negative (preserves Stripe sign convention)" do
    source = FakeSource.new(id: "re_xyz789")
    bt = FakeBT.new(
      id: "txn_2",
      type: "refund",
      amount: -1000,
      fee: 0,
      net: -1000,
      currency: "eur",
      created: Time.utc(2026, 5, 27, 12, 0).to_i,
      description: nil,
      reporting_category: "refund",
      source: source
    )

    row = StripePayoutBuilder.row_for(bt)

    assert_equal "Refund", row[:type]
    assert_equal "re_xyz789", row[:stripe_id]
    assert_equal(-10.00.to_d, row[:amount])
  end

  test "row_for stripe fees get eu_classification 3" do
    source = FakeSource.new(id: "fee_001")
    bt = FakeBT.new(
      id: "txn_3",
      type: "stripe_fee",
      amount: -174,
      fee: 0,
      net: -174,
      currency: "usd",
      created: Time.utc(2026, 5, 27, 12, 0).to_i,
      description: nil,
      reporting_category: "stripe_fee",
      source: source
    )

    row = StripePayoutBuilder.row_for(bt)

    assert_equal "Stripe Fee", row[:type]
    assert_equal 3, row[:eu_classification]
  end

  test "row_for falls back to source.description when bt.description is nil" do
    source = FakeSource.new(id: "ch_001", description: "Charged customer")
    bt = FakeBT.new(
      id: "txn_4",
      type: "charge",
      amount: 1000,
      fee: 0,
      net: 1000,
      currency: "usd",
      created: Time.utc(2026, 5, 27).to_i,
      description: nil,
      reporting_category: "charge",
      source: source
    )

    row = StripePayoutBuilder.row_for(bt)
    assert_equal "Charged customer", row[:description]
  end

  test "row_for extracts customer from expanded source" do
    customer = Struct.new(:id, :email, :name).new(
      "cus_001", "buyer@example.com", "Buyer Name"
    )
    source = FakeSource.new(id: "ch_001", customer: customer)
    bt = FakeBT.new(
      id: "txn_5",
      type: "charge",
      amount: 1000,
      fee: 0,
      net: 1000,
      currency: "usd",
      created: Time.utc(2026, 5, 27).to_i,
      description: nil,
      reporting_category: "charge",
      source: source
    )

    row = StripePayoutBuilder.row_for(bt)
    assert_equal "cus_001", row[:customer_id]
    assert_equal "buyer@example.com", row[:customer_email]
    assert_equal "Buyer Name", row[:customer_name]
  end

  test "build_name is a thin wrapper over PayoutName.from" do
    assert_equal "JUN 1 - 2026", StripePayoutBuilder.build_name(Date.new(2026, 6, 1))
    assert_equal "Unknown Period", StripePayoutBuilder.build_name(nil)
  end
end
