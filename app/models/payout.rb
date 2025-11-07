class Payout < ApplicationRecord
  belongs_to :user
  has_many :payments, dependent: :destroy

  validates :name, presence: true
  validates :period_start, presence: true
  validates :period_end, presence: true
  validate :period_end_after_period_start
  validate :no_overlapping_periods, on: :create

  # Prevent updates after creation (immutability)
  before_update :prevent_updates

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
    'USD'
  end

  private

  def period_end_after_period_start
    return unless period_start && period_end

    errors.add(:period_end, "must be after period start") if period_end < period_start
  end

  def no_overlapping_periods
    return unless user_id && period_start && period_end

    overlapping = user.payouts.where.not(id: id).find do |payout|
      period_overlaps?(payout)
    end

    if overlapping
      errors.add(:base, "Period overlaps with existing payout: #{overlapping.name}")
    end
  end

  def prevent_updates
    # before_update only runs on updates, not creates, so we can raise unconditionally
    raise ActiveRecord::ReadOnlyRecord, "Payouts cannot be updated after creation"
  end
end

