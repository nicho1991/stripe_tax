class PayoutsController < ApplicationController
  def index
    payouts = Current.user.payouts.order(created_at: :desc)
    render inertia: 'Payouts/Index', props: {
      payouts: payouts.map { |p| payout_props(p) }
    }
  end

  def show
    payout = Current.user.payouts.find(params[:id])
    render inertia: 'Payouts/Show', props: {
      payout: payout_props(payout),
      payments: payout.payments.order(created_at_stripe: :desc).map { |p| payment_props(p) }
    }
  end

  def new
    render inertia: 'Payouts/New'
  end

  def create
    csv_file = params[:csv_file]
    period_name = params[:period_name]&.strip

    if csv_file.blank?
      return render inertia: 'Payouts/New', props: {
        errors: { csv_file: ['CSV file is required'] }
      }
    end

    # Read CSV content with UTF-8 encoding
    csv_content = csv_file.read.force_encoding('UTF-8')
    csv_file.rewind

    # Parse CSV
    parser = ::PayoutCsvParser.new(csv_content)
    result = parser.parse

    unless result[:success]
      return render inertia: 'Payouts/New', props: {
        errors: { base: result[:errors] }
      }
    end

    # Use provided period name or default from parser
    final_period_name = period_name.presence || result[:period_name]

    # Create payout with payments
    payout = nil
    ActiveRecord::Base.transaction do
      payout = Current.user.payouts.create!(
        name: final_period_name,
        period_start: result[:period_start],
        period_end: result[:period_end]
      )

      result[:payments].each do |payment_data|
        payout.payments.create!(payment_data)
      end
    end

    redirect_to payout_path(payout), notice: 'Payout created successfully'
  rescue ActiveRecord::RecordInvalid => e
    render inertia: 'Payouts/New', props: {
      errors: { base: [e.record.errors.full_messages.join(', ')] }
    }
  rescue StandardError => e
    render inertia: 'Payouts/New', props: {
      errors: { base: ["An error occurred: #{e.message}"] }
    }
  end

  def update
    payout = Current.user.payouts.find(params[:id])
    
    if payout.update(payout_params)
      redirect_to payout_path(payout), notice: 'Payout renamed successfully'
    else
      render inertia: 'Payouts/Show', props: {
        payout: payout_props(payout),
        payments: payout.payments.order(created_at_stripe: :desc).map { |p| payment_props(p) },
        errors: payout.errors.full_messages
      }
    end
  end

  def destroy
    payout = Current.user.payouts.find(params[:id])
    payout.destroy
    redirect_to payouts_path, notice: 'Payout deleted successfully'
  end

  private

  def payout_params
    params.require(:payout).permit(:name)
  end

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

  def payment_props(payment)
    {
      id: payment.id,
      type: payment.type,
      stripe_id: payment.stripe_id,
      created_at_stripe: payment.created_at_stripe,
      description: payment.description,
      amount: payment.amount.to_f,
      currency: payment.currency,
      converted_amount: payment.converted_amount.to_f,
      fees: payment.fees.to_f,
      net: payment.net.to_f,
      converted_currency: payment.converted_currency,
      details: payment.details,
      customer_id: payment.customer_id,
      customer_email: payment.customer_email,
      customer_name: payment.customer_name
    }
  end
end

