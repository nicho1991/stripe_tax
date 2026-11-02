require "test_helper"

class TransactionImportServiceTest < ActiveSupport::TestCase
  test "imports a new transaction and calculates its classification" do
    result = import_service.import([ transaction_data ])

    transaction = users(:one).transactions.find_by!(transaction_id: "txn_123")
    assert_equal 1, result[:imported]
    assert_equal 0, result[:updated]
    assert_equal 0, result[:skipped]
    assert_equal "DE", transaction.card_address_country
    assert_equal 1, transaction.location_confidence_score
    assert_equal "eu", transaction.eu_classification
  end

  test "updates an existing transaction with the latest data" do
    transaction = users(:one).transactions.create!(
      transaction_id: "txn_123",
      created_at_stripe: Time.zone.parse("2025-11-05 10:20:12"),
      status: "Paid",
      raw_data: { "id" => "txn_123" }
    )

    result = import_service.import([
      transaction_data(card_address_country: "DE", raw_data: { "id" => "txn_123", "country" => "DE" })
    ])

    transaction.reload
    assert_equal 0, result[:imported]
    assert_equal 1, result[:updated]
    assert_equal 0, result[:skipped]
    assert_equal "DE", transaction.card_address_country
    assert_equal 1, transaction.location_confidence_score
    assert_equal "eu", transaction.eu_classification
    assert_equal({ "id" => "txn_123", "country" => "DE" }, transaction.raw_data)
  end

  test "skips an existing transaction when its imported data is unchanged" do
    data = transaction_data
    users(:one).transactions.create!(
      data.except(:raw_data).merge(raw_data: data[:raw_data], eu_classification: :eu, location_confidence_score: 1)
    )

    result = import_service.import([ data ])

    assert_equal 0, result[:imported]
    assert_equal 0, result[:updated]
    assert_equal 1, result[:skipped]
  end

  private

  def import_service
    TransactionImportService.new(users(:one))
  end

  def transaction_data(card_address_country: "DE", raw_data: { "id" => "txn_123" })
    {
      transaction_id: "txn_123",
      created_at_stripe: Time.zone.parse("2025-11-05 10:20:12"),
      status: "Paid",
      decline_reason: nil,
      card_address_country: card_address_country,
      card_issue_country: nil,
      shipping_address_country: nil,
      raw_data: raw_data
    }
  end
end
