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
    # Per-user Stripe configuration drives the "Fetch from Stripe"
    # tab on the New page (server-side rendered via Inertia). When
    # the current user hasn't saved a Stripe API key in Settings,
    # the tab is disabled on the client and the user gets a banner
    # explaining the missing setup. The fallback chain is:
    # User#stripe_secret_key (DB-encrypted) → ENV["STRIPE_SECRET_KEY"]
    # → credentials (bootstrap) — see StripeClient#resolve.
    render inertia: "Payouts/New", props: {
      stripe_configured: stripe_configured_for_current_user
    }
  end

  # Whether `Current.user` has a usable Stripe API key. Used by the
  # New page to decide whether to enable the "Fetch from Stripe"
  # tab. The DB column is the source of truth; env/credentials are
  # the fallback chain and aren't visible to a single user in
  # multi-tenant setups anyway.
  def stripe_configured_for_current_user
    Current.user&.stripe_configured? ||
      ENV["STRIPE_SECRET_KEY"].present? ||
      Rails.application.credentials.dig(:stripe, :secret_key).present?
  end
  helper_method :stripe_configured_for_current_user

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

  # Phase 2 — fetch a Stripe payout and import it directly. Reads
  # the per-user Stripe API key from the User model (encrypted at
  # rest via Active Record encryption). Falls back to ENV /
  # credentials for dev/CI users who haven't yet saved a key in
  # Settings.
  def fetch
    start_date = parse_date_param(params[:start_date])
    end_date = parse_date_param(params[:end_date])

    if start_date.blank? || end_date.blank?
      return render inertia: "Payouts/New", props: {
        errors: { base: [ "Start date and end date are required" ] }
      }
    end

    stripe_key = resolve_stripe_key_for(Current.user)
    if stripe_key.blank?
      return redirect_to settings_path, alert: "Set your Stripe API key in Settings before fetching from Stripe."
    end

    result = PayoutImporter.call(
      source: :stripe_api,
      user: Current.user,
      start_date: start_date,
      end_date: end_date,
      stripe_key: stripe_key
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

  # Per-user Stripe API key resolution for the :stripe_api branch.
  # Order:
  #   1. user.stripe_secret_key  (DB-encrypted via Rails 7+ Active
  #                               Record encryption; per-user)
  #   2. ENV["STRIPE_SECRET_KEY"]  (dev/CI fallback)
  #   3. Rails.application.credentials.dig(:stripe, :secret_key)
  #      (bootstrap fallback for the first-run case where no user
  #      has configured their own key yet)
  # Returns nil when none of the three resolves, so the controller
  # can render a friendly redirect-to-Settings.
  def resolve_stripe_key_for(user)
    return ENV["STRIPE_SECRET_KEY"] if ENV["STRIPE_SECRET_KEY"].present?
    return Rails.application.credentials.dig(:stripe, :secret_key) if Rails.application.credentials.dig(:stripe, :secret_key).present?

    user&.stripe_secret_key
  end
end
