require "test_helper"

class PayoutsControllerTest < ActionDispatch::IntegrationTest
  # Mirrors the sample CSV the importer tests use — keeps fixture
  # data consistent across the suite.
  SAMPLE_CSV = <<~CSV
    Type,ID,Created,Description,Amount,Currency,Converted Amount,Fees,Net,Converted Currency,Details,Customer ID,Customer Email,Customer Name
    Charge,ch_abc123,2026-05-27 12:00,Order #1234,49.99,USD,49.99,1.74,48.25,USD,charge,cus_001,buyer@example.com,Buyer
    Stripe Fee,fee_001,2026-05-27 12:00,Stripe fee,-1.74,USD,-1.74,0.00,-1.74,USD,stripe_fee,,,
  CSV

  setup do
    # Sign the user fixture in by hitting the real sessions#create
    # endpoint. The auth concern writes a signed session_id cookie
    # via `cookies.signed.permanent[:session_id]`; this persists
    # across subsequent requests in the same integration test. This
    # is the only reliable way to set up auth in Rails integration
    # tests with this app's custom cookie-based auth concern.
    post session_path, params: {
      email_address: users(:one).email_address,
      password: "password"
    }
  end

  teardown do
    # Drop the session cookie + DB row so each test starts clean.
    delete session_path
    users(:one).sessions.destroy_all
  end

  # --- #create (CSV path) ---

  test "create with valid CSV + arrival_date persists a Payout with the derived name" do
    csv_file = Rack::Test::UploadedFile.new(
      StringIO.new(SAMPLE_CSV),
      "text/csv",
      original_filename: "payout.csv"
    )

    assert_difference -> { Payout.count }, 1 do
      post payouts_path, params: {
        csv_file: csv_file,
        arrival_date: "2026-06-01"
      }
    end

    assert_redirected_to payout_path(Payout.last)
    payout = Payout.last
    assert_equal "JUN 1 - 2026", payout.name
    assert_equal Date.new(2026, 6, 1), payout.arrival_date
    assert_equal 2, payout.payments.count
  end

  test "create ignores params[:period_name] (Phase 3 UX fix)" do
    csv_file = Rack::Test::UploadedFile.new(
      StringIO.new(SAMPLE_CSV),
      "text/csv",
      original_filename: "payout.csv"
    )

    post payouts_path, params: {
      csv_file: csv_file,
      arrival_date: "2026-06-01",
      period_name: "I-TYPED-SOMETHING-WRONG"
    }

    payout = Payout.last
    assert_equal "JUN 1 - 2026", payout.name,
      "expected the form-typed period_name to be ignored; got #{payout.name.inspect}"
  end

  test "create with missing arrival_date shows a validation error" do
    csv_file = Rack::Test::UploadedFile.new(
      StringIO.new(SAMPLE_CSV),
      "text/csv",
      original_filename: "payout.csv"
    )

    assert_no_difference -> { Payout.count } do
      post payouts_path, params: { csv_file: csv_file }
    end

    assert_response :success
    assert_match(/Payout Date is required/, response.body)
  end

  test "create with missing CSV file shows an error" do
    assert_no_difference -> { Payout.count } do
      post payouts_path, params: { arrival_date: "2026-06-01" }
    end

    assert_response :success
    assert_match(/CSV file is required/, response.body)
  end

  # --- #fetch (Stripe API path) ---

  test "fetch with valid dates + configured Stripe creates a Payout" do
    payout_struct = Struct.new(:id, :arrival_date).new(
      "po_test_001", Time.utc(2026, 7, 1, 12, 0).to_i
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
    payouts_resource.define_singleton_method(:list) do |**|
      Struct.new(:data).new([ payout_struct ])
    end

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

    fake_client = Object.new
    fake_client.define_singleton_method(:v1) { v1 }

    original_client = StripeClient.method(:client)
    original_configured = StripeClient.method(:configured?)
    StripeClient.define_singleton_method(:client) { fake_client }
    StripeClient.define_singleton_method(:configured?) { true }

    assert_difference -> { Payout.count }, 1 do
      post fetch_payouts_path, params: {
        start_date: "2026-07-01",
        end_date: "2026-07-31"
      }
    end

    payout = Payout.last
    assert_equal "JUL 1 - 2026", payout.name
    assert_equal Date.new(2026, 7, 1), payout.arrival_date
    assert_redirected_to payout_path(payout)
  ensure
    StripeClient.define_singleton_method(:client, original_client)
    StripeClient.define_singleton_method(:configured?, original_configured)
  end

  test "fetch without configured Stripe credentials shows a server error" do
    original_configured = StripeClient.method(:configured?)
    StripeClient.define_singleton_method(:configured?) { false }

    assert_no_difference -> { Payout.count } do
      post fetch_payouts_path, params: {
        start_date: "2026-07-01",
        end_date: "2026-07-31"
      }
    end

    assert_response :success
    assert_match(/credentials missing/i, response.body)
  ensure
    StripeClient.define_singleton_method(:configured?, original_configured)
  end

  test "fetch without dates shows a validation error" do
    assert_no_difference -> { Payout.count } do
      post fetch_payouts_path
    end

    assert_response :success
    assert_match(/Start date and end date are required/, response.body)
  end

  test "fetch when no Stripe payout is found in the window shows the importer's message" do
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

    fake_client = Object.new
    fake_client.define_singleton_method(:v1) { v1 }

    original_client = StripeClient.method(:client)
    original_configured = StripeClient.method(:configured?)
    StripeClient.define_singleton_method(:client) { fake_client }
    StripeClient.define_singleton_method(:configured?) { true }

    assert_no_difference -> { Payout.count } do
      post fetch_payouts_path, params: {
        start_date: "2026-07-01",
        end_date: "2026-07-31"
      }
    end

    assert_response :success
    assert_match(/no stripe payout found/i, response.body)
  ensure
    StripeClient.define_singleton_method(:client, original_client)
    StripeClient.define_singleton_method(:configured?, original_configured)
  end
end
