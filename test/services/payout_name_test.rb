require "test_helper"

class PayoutNameTest < ActiveSupport::TestCase
  test "from formats a Stripe arrival date in dashboard style for double-digit day" do
    assert_equal "JUN 1 - 2026", PayoutName.from(Date.new(2026, 6, 1))
    assert_equal "MAY 27 - 2025", PayoutName.from(Date.new(2025, 5, 27))
  end

  test "from strips leading zeros from the day" do
    # Stripe's dashboard shows "JUN 1 - 2026" not "JUN 01 - 2026".
    assert_equal "JAN 5 - 2026", PayoutName.from(Date.new(2026, 1, 5))
  end

  test "from handles single-digit day without padding" do
    assert_equal "DEC 3 - 2024", PayoutName.from(Date.new(2024, 12, 3))
  end

  test "from handles last day of month" do
    assert_equal "OCT 31 - 2025", PayoutName.from(Date.new(2025, 10, 31))
  end

  test "from returns 'Unknown Period' for nil" do
    assert_equal "Unknown Period", PayoutName.from(nil)
  end

  test "from uses uppercase month abbreviation matching Stripe dashboard" do
    # The format is intentionally matching Stripe's display, which
    # uses uppercase month abbreviations without a dot.
    assert_equal "NOV 15 - 2024", PayoutName.from(Date.new(2024, 11, 15))
  end
end
