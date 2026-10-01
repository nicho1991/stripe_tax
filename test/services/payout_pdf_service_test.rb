require "test_helper"

class PayoutPdfServiceTest < ActiveSupport::TestCase
  setup do
    @user   = users(:one)
    @payout = @user.payouts.create!(
      name:         "Test Payout #{SecureRandom.hex(4)}",
      period_start: Date.new(2026, 3, 1),
      period_end:   Date.new(2026, 3, 31)
    )
    @service = PayoutPdfService.new(@payout, :eu)
  end

  # Bug repro: PayoutPdfService#customer_country_code used to read only the
  # underlying Transaction's country fields. When a user manually set
  # `manual_country_code` on a Payment to an EU country but the Transaction
  # still pointed to a non-EU country, the Cntry column in the rendered PDF
  # showed the wrong code (e.g. "KI" instead of "DK"), making the row look
  # like a non-EU payment had slipped into the EU PDF. The fix routes the
  # payment's manual_country_code through customer_country_code.
  test "customer_country_code returns manual_country_code when set" do
    payment = build_payment(manual_country_code: "DK")
    transaction = build_transaction(payment,
      card_address_country: "KI",
      card_issue_country:   "PL")

    assert_equal "DK", @service.send(:customer_country_code, transaction, payment.manual_country_code)
  end

  test "customer_country_code falls back to transaction country when no manual override" do
    payment = build_payment(manual_country_code: nil)
    transaction = build_transaction(payment, card_address_country: "FR")

    assert_equal "FR", @service.send(:customer_country_code, transaction, payment.manual_country_code)
  end

  test "customer_country_code returns nil when no manual override and no transaction" do
    payment = build_payment(manual_country_code: nil)

    assert_nil @service.send(:customer_country_code, nil, payment.manual_country_code)
  end

  test "customer_country_code returns nil when no manual override and transaction has no country" do
    payment = build_payment(manual_country_code: nil)
    transaction = build_transaction(payment)

    assert_nil @service.send(:customer_country_code, transaction, payment.manual_country_code)
  end

  test "customer_country_code prefers card_address_country over card_issue_country" do
    payment = build_payment(manual_country_code: nil)
    transaction = build_transaction(payment,
      card_address_country: "DE",
      card_issue_country:   "FR")

    assert_equal "DE", @service.send(:customer_country_code, transaction, payment.manual_country_code)
  end

  # The filter that decides which section of the PDF a payment belongs to
  # mirrors the Show page logic: manual_country_code wins, then
  # customer-influenced classification (which lifts undetermined via
  # cross-transaction inference), then the raw enum.
  test "filtered_payments routes a manual-override payment into the EU section" do
    payment = build_payment(manual_country_code: "DE")
    # no transaction → would otherwise be undetermined

    filtered = @service.send(:filtered_payments)

    assert_includes filtered, payment,
      "Payment with manual_country_code='DE' should be included in the EU PDF"
  end

  test "filtered_payments excludes manual-override payment when section is :non_eu" do
    payment = build_payment(manual_country_code: "DE")
    non_eu_service = PayoutPdfService.new(@payout, :non_eu)

    filtered = non_eu_service.send(:filtered_payments)

    refute_includes filtered, payment,
      "Payment with manual_country_code='DE' should NOT appear in the Non-EU PDF"
  end

  # Bug repro for the elevation regression: a payment with a transaction
  # that has no country data on its own, but the customer has other
  # transactions with country data, gets "elevated" to eu/non_eu by
  # Transaction#customer_influenced_eu_classification. The Show page
  # uses that elevation; the PDF must too, or these payments silently
  # vanish from the EU/Non-EU PDFs (the undetermined PDF swallows them).
  test "filtered_payments routes a customer-influenced-elevated payment into the Non-EU section" do
    same_customer = "cus_elevated_#{SecureRandom.hex(4)}"

    # Anchor: a transaction for the same customer with a real non-EU country
    anchor_payment   = build_payment(stripe_id: "ch_anchor_#{SecureRandom.hex(4)}", customer_id: same_customer)
    anchor_payment.update!(customer_id: same_customer)
    build_transaction(anchor_payment, card_address_country: "US")

    # Elevated: another transaction for the same customer, but with NO country data
    elevated_payment = build_payment(stripe_id: "ch_elevated_#{SecureRandom.hex(4)}", customer_id: same_customer)
    elevated_payment.update!(customer_id: same_customer)
    build_transaction(elevated_payment) # no country fields

    non_eu_service = PayoutPdfService.new(@payout, :non_eu)
    filtered = non_eu_service.send(:filtered_payments)

    assert_includes filtered, elevated_payment,
      "Payment elevated to non_eu via cross-transaction inference " \
      "should appear in the Non-EU PDF"
  end

  test "filtered_payments routes a customer-influenced-elevated payment into the EU section" do
    same_customer = "cus_elevated_eu_#{SecureRandom.hex(4)}"

    anchor_payment = build_payment(stripe_id: "ch_anchor_#{SecureRandom.hex(4)}", customer_id: same_customer)
    anchor_payment.update!(customer_id: same_customer)
    build_transaction(anchor_payment, card_address_country: "DE")

    elevated_payment = build_payment(stripe_id: "ch_elevated_#{SecureRandom.hex(4)}", customer_id: same_customer)
    elevated_payment.update!(customer_id: same_customer)
    build_transaction(elevated_payment) # no country fields

    filtered = @service.send(:filtered_payments)

    assert_includes filtered, elevated_payment,
      "Payment elevated to eu via cross-transaction inference " \
      "should appear in the EU PDF"
  end

  test "filtered_payments leaves an undetermined payment in the Undetermined section when no elevation" do
    payment = build_payment # no manual code, no transaction → undetermined
    # explicit transaction to be sure
    build_transaction(payment)

    und_service = PayoutPdfService.new(@payout, :undetermined)
    filtered    = und_service.send(:filtered_payments)

    assert_includes filtered, payment,
      "A truly undetermined payment (no manual code, no inference lift) " \
      "should still appear in the Undetermined PDF"
  end

  test "payment_classification prefers manual_country_code over customer-influenced elevation" do
    # Manual override should always win, even if the customer-influenced
    # classification would say something different.
    payment = build_payment(manual_country_code: "US")
    build_transaction(payment, card_address_country: "DE") # would otherwise lift to :eu

    assert_equal :non_eu, @service.send(:payment_classification, payment),
      "manual_country_code='US' should override any customer-influenced lift to :eu"
  end

  private

  def build_payment(manual_country_code: nil, type: "Charge", stripe_id: nil, customer_id: nil)
    @payout.payments.create!(
      type:                type,
      stripe_id:           stripe_id || "ch_#{SecureRandom.hex(8)}",
      created_at_stripe:   Time.zone.parse("2026-03-15 12:00:00"),
      amount:              100.00,
      converted_amount:    100.00,
      fees:                5.00,
      net:                 95.00,
      currency:            "USD",
      converted_currency:  "dkk",
      customer_id:         customer_id,
      manual_country_code: manual_country_code,
      eu_classification:   0 # undetermined; effective_eu_classification will still honour the override
    )
  end

  def build_transaction(payment, card_address_country: nil, card_issue_country: nil, shipping_address_country: nil)
    Transaction.create!(
      transaction_id:           payment.stripe_id,
      user:                     @user,
      created_at_stripe:        payment.created_at_stripe,
      card_address_country:     card_address_country,
      card_issue_country:       card_issue_country,
      shipping_address_country: shipping_address_country,
      eu_classification:        0
    )
  end
end
