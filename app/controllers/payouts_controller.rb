class PayoutsController < ApplicationController
  def index
    payouts = Current.user.payouts.order(created_at: :desc)

    # Pagination
    page = params[:page]&.to_i || 1
    per_page = 25
    total_count = payouts.count
    total_pages = (total_count.to_f / per_page).ceil
    paginated_payouts = payouts.limit(per_page).offset((page - 1) * per_page)

    render inertia: "Payouts/Index", props: {
      payouts: paginated_payouts.map { |p| payout_props(p) },
      pagination: {
        current_page: page,
        total_pages: total_pages,
        total_count: total_count,
        per_page: per_page
      }
    }
  end

  def show
    payout = Current.user.payouts.find(params[:id])
    render inertia: "Payouts/Show", props: {
      payout: payout_props(payout),
      payments: payout.payments.order(created_at_stripe: :desc).map { |p| payment_props(p) }
    }
  end

  def new
    render inertia: "Payouts/New"
  end

  def create
    csv_file = params[:csv_file]
    arrival_date = parse_arrival_date_param(params[:arrival_date])

    if csv_file.blank?
      return render inertia: "Payouts/New", props: {
        errors: { csv_file: [ "CSV file is required" ] }
      }
    end

    if arrival_date.blank?
      return render inertia: "Payouts/New", props: {
        errors: { arrival_date: [ "Payout Date is required" ] }
      }
    end

    # Phase 3: the form no longer asks for a free-form period name.
    # PayoutImporter derives the name from `arrival_date` via
    # `PayoutName.from`. The :csv branch is bit-for-bit equivalent to
    # what the controller did before Phase 1.
    result = PayoutImporter.call(
      source: :csv,
      user: Current.user,
      csv_file: csv_file,
      arrival_date: arrival_date
    )

    if result.success?
      redirect_to payout_path(result.payout), notice: "Payout created successfully"
    else
      render inertia: "Payouts/New", props: { errors: { base: result.errors } }
    end
  end

  # Phase 2 — fetch a Stripe payout and import it directly. Equivalent
  # to the CSV path, but reads from Stripe API instead of accepting
  # an upload. Reachable only when `StripeClient.configured?` is true;
  # the importer raises a friendly error otherwise.
  def fetch
    start_date = parse_date_param(params[:start_date])
    end_date = parse_date_param(params[:end_date])

    if start_date.blank? || end_date.blank?
      return render inertia: "Payouts/New", props: {
        errors: { base: [ "Start date and end date are required" ] }
      }
    end

    result = PayoutImporter.call(
      source: :stripe_api,
      user: Current.user,
      start_date: start_date,
      end_date: end_date
    )

    if result.success?
      redirect_to payout_path(result.payout), notice: "Payout fetched from Stripe"
    else
      render inertia: "Payouts/New", props: { errors: { base: result.errors } }
    end
  end

  def update
    payout = Current.user.payouts.find(params[:id])

    if payout.update(payout_params)
      redirect_to payout_path(payout), notice: "Payout renamed successfully"
    else
      render inertia: "Payouts/Show", props: {
        payout: payout_props(payout),
        payments: payout.payments.order(created_at_stripe: :desc).map { |p| payment_props(p) },
        errors: payout.errors.full_messages
      }
    end
  end

  def update_payment_country
    payout = Current.user.payouts.find(params[:id])
    payment = payout.payments.find(params[:payment_id])

    if payment.update(manual_country_code: params[:manual_country_code].presence)
      render json: { success: true, effective_eu_classification: payment.effective_eu_classification, eu_classification: payment.eu_classification }
    else
      render json: { success: false, errors: payment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    payout = Current.user.payouts.find(params[:id])
    payout.destroy
    redirect_to payouts_path, notice: "Payout deleted successfully"
  end

  def pdf_eu
    generate_pdf(:eu, "EU")
  end

  def pdf_non_eu
    generate_pdf(:non_eu, "Non-EU")
  end

  def pdf_undetermined
    generate_pdf(:undetermined, "Undetermined")
  end

  def pdf_stripe_fees
    generate_pdf(:stripe_fees, "Stripe Fees")
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
      arrival_date: payout.arrival_date,
      total_amount: payout.total_amount.to_f,
      total_fees: payout.total_fees.to_f,
      total_net: payout.total_net.to_f,
      primary_currency: payout.primary_currency,
      payments_count: payout.payments.count,
      created_at: payout.created_at
    }
  end

  def payment_props(payment)
    customer_link = payment.customer_id.present? ? customer_path(payment.customer_id) : nil

    transaction = payment.stripe_transaction
    enhanced_data = if transaction
      enhancement = transaction.enhanced_location_confidence
      classification = transaction.customer_influenced_eu_classification

      {
        location_confidence_score: transaction.location_confidence_score,
        enhanced_location_confidence_score: enhancement[:enhanced_score],
        inferred_fields: enhancement[:inferred_fields],
        inferred_data: enhancement[:inferred_data],
        eu_classification: transaction.eu_classification,
        customer_influenced_eu_classification: classification[:customer_influenced],
        card_address_country: transaction.card_address_country,
        card_issue_country: transaction.card_issue_country,
        shipping_address_country: transaction.shipping_address_country
      }
    else
      {
        location_confidence_score: 0,
        enhanced_location_confidence_score: 0,
        inferred_fields: [],
        inferred_data: {},
        eu_classification: payment.eu_classification,
        customer_influenced_eu_classification: payment.eu_classification,
        card_address_country: nil,
        card_issue_country: nil,
        shipping_address_country: nil
      }
    end

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
      customer_name: payment.customer_name,
      customer_link: customer_link,
      has_transaction: payment.stripe_transaction.present?,
      transaction_id: payment.stripe_transaction&.id,
      manual_country_code: payment.manual_country_code,
      effective_eu_classification: payment.effective_eu_classification,
      **enhanced_data
    }
  end

  def generate_pdf(classification_type, label)
    payout = Current.user.payouts.find(params[:id])
    pdf_data = PayoutPdfService.generate(payout, classification_type)

    filename = "#{payout.name.parameterize}-#{label.parameterize}-#{Date.current}.pdf"

    send_data pdf_data,
              filename: filename,
              type: "application/pdf",
              disposition: "attachment"
  end

  # Parse a YYYY-MM-DD date param safely; returns nil for blank /
  # malformed input rather than raising. Form fields come through
  # as ActionDispatch::Http::UploadedFile for file inputs and as
  # strings for date inputs — we coerce here.
  def parse_date_param(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
  alias_method :parse_arrival_date_param, :parse_date_param
end
