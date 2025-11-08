require "test_helper"

class EuClassificationServiceTest < ActiveSupport::TestCase
  # Helper method to create a mock transaction
  def create_transaction(card_address_country: nil, card_issue_country: nil, shipping_address_country: nil)
    Struct.new(:card_address_country, :card_issue_country, :shipping_address_country).new(
      card_address_country,
      card_issue_country,
      shipping_address_country
    )
  end

  # Test classify_country method
  test "classify_country returns non_eu for Norway (NO)" do
    result = EuClassificationService.classify_country("NO")
    assert_equal :non_eu, result, "Norway (NO) is not in EU VAT and should be classified as non_eu"
  end

  test "classify_country returns non_eu for Iceland (IS)" do
    result = EuClassificationService.classify_country("IS")
    assert_equal :non_eu, result, "Iceland (IS) is not in EU VAT and should be classified as non_eu"
  end

  test "classify_country returns non_eu for Liechtenstein (LI)" do
    result = EuClassificationService.classify_country("LI")
    assert_equal :non_eu, result, "Liechtenstein (LI) is not in EU VAT and should be classified as non_eu"
  end

  test "classify_country returns eu for Germany (DE)" do
    result = EuClassificationService.classify_country("DE")
    assert_equal :eu, result
  end

  test "classify_country returns eu for France (FR)" do
    result = EuClassificationService.classify_country("FR")
    assert_equal :eu, result
  end

  test "classify_country returns nil for nil country code" do
    result = EuClassificationService.classify_country(nil)
    assert_nil result
  end

  test "classify_country returns nil for blank country code" do
    result = EuClassificationService.classify_country("")
    assert_nil result
  end

  test "classify_country returns nil for invalid country code" do
    result = EuClassificationService.classify_country("XX")
    assert_nil result
  end

  test "classify_country handles lowercase country codes" do
    result = EuClassificationService.classify_country("no")
    assert_equal :non_eu, result, "Should handle lowercase 'no' and classify as non_eu"
  end

  # Test classify_transaction with NO in individual fields
  test "classify_transaction with only card_address_country NO returns non_eu" do
    transaction = create_transaction(card_address_country: "NO")
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :non_eu, result, "Transaction with card_address_country='NO' should be non_eu"
  end

  test "classify_transaction with only card_issue_country NO returns non_eu" do
    transaction = create_transaction(card_issue_country: "NO")
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :non_eu, result, "Transaction with card_issue_country='NO' should be non_eu"
  end

  test "classify_transaction with only shipping_address_country NO returns non_eu" do
    transaction = create_transaction(shipping_address_country: "NO")
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :non_eu, result, "Transaction with shipping_address_country='NO' should be non_eu"
  end

  test "classify_transaction with all three fields set to NO returns non_eu" do
    transaction = create_transaction(
      card_address_country: "NO",
      card_issue_country: "NO",
      shipping_address_country: "NO"
    )
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :non_eu, result, "Transaction with all fields='NO' should be non_eu"
  end

  # Test classify_transaction with various combinations
  test "classify_transaction with NO and EU VAT country returns undetermined" do
    transaction = create_transaction(
      card_address_country: "NO",
      card_issue_country: "DE"
    )
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :undetermined, result, "NO is non_eu and DE is eu, so should be undetermined"
  end

  test "classify_transaction with NO in one field and EU VAT in another returns undetermined" do
    transaction = create_transaction(
      card_address_country: "NO",
      shipping_address_country: "FR"
    )
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :undetermined, result, "NO is non_eu and FR is eu, so should be undetermined"
  end

  test "classify_transaction with no country data returns undetermined" do
    transaction = create_transaction
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :undetermined, result
  end

  test "classify_transaction with all EU countries returns eu" do
    transaction = create_transaction(
      card_address_country: "DE",
      card_issue_country: "FR",
      shipping_address_country: "IT"
    )
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :eu, result
  end

  test "classify_transaction with single EU country returns eu" do
    transaction = create_transaction(card_address_country: "DE")
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :eu, result
  end

  test "classify_transaction with all non-EU countries returns non_eu" do
    transaction = create_transaction(
      card_address_country: "US",
      card_issue_country: "CA",
      shipping_address_country: "JP"
    )
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :non_eu, result
  end

  test "classify_transaction with NO and non-EU countries returns non_eu" do
    transaction = create_transaction(
      card_address_country: "NO",
      card_issue_country: "US"
    )
    result = EuClassificationService.classify_transaction(transaction)
    assert_equal :non_eu, result, "NO and US are both non_eu, so should be non_eu"
  end

  # Test calculate_confidence method
  test "calculate_confidence returns 0 for transaction with no country data" do
    transaction = create_transaction
    result = EuClassificationService.calculate_confidence(transaction)
    assert_equal 0, result
  end

  test "calculate_confidence returns 1 for transaction with one country field" do
    transaction = create_transaction(card_address_country: "DE")
    result = EuClassificationService.calculate_confidence(transaction)
    assert_equal 1, result
  end

  test "calculate_confidence returns 1 for transaction with only card_issue_country" do
    transaction = create_transaction(card_issue_country: "NO")
    result = EuClassificationService.calculate_confidence(transaction)
    assert_equal 1, result
  end

  test "calculate_confidence returns 1 for transaction with only shipping_address_country" do
    transaction = create_transaction(shipping_address_country: "FR")
    result = EuClassificationService.calculate_confidence(transaction)
    assert_equal 1, result
  end

  test "calculate_confidence returns 2 for transaction with two country fields" do
    transaction = create_transaction(
      card_address_country: "DE",
      card_issue_country: "NO"
    )
    result = EuClassificationService.calculate_confidence(transaction)
    assert_equal 2, result
  end

  test "calculate_confidence returns 3 for transaction with all three country fields" do
    transaction = create_transaction(
      card_address_country: "DE",
      card_issue_country: "NO",
      shipping_address_country: "FR"
    )
    result = EuClassificationService.calculate_confidence(transaction)
    assert_equal 3, result
  end

  test "calculate_confidence counts only present fields" do
    transaction = create_transaction(
      card_address_country: "DE",
      card_issue_country: nil,
      shipping_address_country: "FR"
    )
    result = EuClassificationService.calculate_confidence(transaction)
    assert_equal 2, result
  end
end
