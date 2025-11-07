class DashboardController < ApplicationController
  def index
    recent_payouts = Current.user.payouts.order(created_at: :desc).limit(5)
    all_payouts = Current.user.payouts
    
    # Calculate totals across all payouts
    total_amount = all_payouts.sum(&:total_amount).to_f
    total_fees = all_payouts.sum(&:total_fees).to_f
    total_net = all_payouts.sum(&:total_net).to_f
    
    # Get primary currency (most common currency across payouts)
    primary_currency = all_payouts.map(&:primary_currency).compact.group_by(&:itself).max_by { |_, v| v.length }&.first || 'USD'
    
    render inertia: 'Dashboard/Index', props: {
      recent_payouts: recent_payouts.map { |p| payout_props(p) },
      total_payouts: all_payouts.count,
      totals: {
        total_amount: total_amount,
        total_fees: total_fees,
        total_net: total_net,
        primary_currency: primary_currency
      }
    }
  end

  private

  def payout_props(payout)
    {
      id: payout.id,
      name: payout.name,
      period_start: payout.period_start,
      period_end: payout.period_end,
      total_amount: payout.total_amount.to_f,
      total_fees: payout.total_fees.to_f,
      total_net: payout.total_net.to_f,
      primary_currency: payout.primary_currency,
      payments_count: payout.payments.count,
      created_at: payout.created_at
    }
  end
end

