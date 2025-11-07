class DashboardController < ApplicationController
  def index
    recent_payouts = Current.user.payouts.order(created_at: :desc).limit(5)
    render inertia: 'Dashboard/Index', props: {
      recent_payouts: recent_payouts.map { |p| payout_props(p) },
      total_payouts: Current.user.payouts.count
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

