class Payout < ApplicationRecord
  belongs_to :user
  has_many :payments, dependent: :destroy

  validates :name, presence: true
  validates :period_start, presence: true
  validates :period_end, presence: true
  validate :period_end_after_period_start
  validate :no_overlapping_periods, on: :create

  # Allow name updates but prevent period date changes (immutability for period)
  before_update :prevent_period_changes

  def period_overlaps?(other_payout)
    return false if other_payout.id == id

    period_start <= other_payout.period_end && period_end >= other_payout.period_start
  end

  # Use converted_amount for totals since fees and net are in converted currency
  def total_amount
    payments.sum(:converted_amount) || 0
  end

  def total_fees
    payments.sum(:fees) || 0
  end

  def total_net
    payments.sum(:net) || 0
  end

  # Get the primary currency (converted currency) for this payout
  def primary_currency
    payments.where.not(converted_currency: nil).first&.converted_currency ||
    payments.where.not(currency: nil).first&.currency ||
    "USD"
  end

  private

  def period_end_after_period_start
    return unless period_start && period_end

    errors.add(:period_end, "must be after period start") if period_end < period_start
  end

  def no_overlapping_periods
    return unless user_id && period_start && period_end

    overlapping = user.payouts.where.not(id: id).find do |payout|
      period_overlaps?(payout) && !overlap_only_stripe_fees?(payout)
    end

    if overlapping
      errors.add(:base, "Period overlaps with existing payout: #{overlapping.name}")
    end
  end

  def overlap_only_stripe_fees?(other_payout)
    # Calculate the overlapping date range
    overlap_start = [ period_start, other_payout.period_start ].max
    overlap_end = [ period_end, other_payout.period_end ].min

    # For the new payout being created, payments don't exist yet, so we can't check them
    # But we can check the existing payout (other_payout) - if it only has stripe fees
    # in the overlap, allow it. This handles the case where November payout has a stripe
    # fee on Dec 1 and December payout starts on Dec 1.

    # Check if other (existing) payout only has stripe fees in the overlap range
    other_payments_in_overlap = other_payout.payments.where(
      "DATE(created_at_stripe) >= ? AND DATE(created_at_stripe) <= ?",
      overlap_start, overlap_end
    )

    # If there are no payments in the overlap, it's not a real overlap concern
    return true if other_payments_in_overlap.empty?

    # Allow overlap if the existing payout only has stripe fees in the overlapping period
    !other_payments_in_overlap.where.not(type: "Stripe Fee").exists?
  end

  def prevent_period_changes
    # Only allow name changes, not period date changes
    if period_start_changed? || period_end_changed?
      errors.add(:base, "Period dates cannot be changed after creation")
      throw :abort
    end
  end
end
