module PayoutName
  module_function

  # Build a payout name from a Stripe arrival date in the dashboard's
  # display format: "JUN 1 - 2026", "MAY 27 - 2025". Returns
  # "Unknown Period" for nil so callers never have to nil-check.
  #
  # Used by both the Stripe API import path (the actual arrival_date
  # from Stripe::Payout) and (in Phase 3) by the CSV path (the
  # user-provided payout date input). One source of truth for the
  # naming format.
  def from(arrival_date)
    return "Unknown Period" if arrival_date.nil?

    "#{arrival_date.strftime('%b').upcase} #{arrival_date.day} - #{arrival_date.year}"
  end
end
