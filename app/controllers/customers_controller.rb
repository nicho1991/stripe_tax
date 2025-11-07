class CustomersController < ApplicationController
  def index
    # Get all unique customers (grouped by customer_id) with summary stats
    customers_data = Payment.joins(:payout)
                            .where(payouts: { user_id: Current.user.id })
                            .where.not(customer_id: nil)
                            .select('payments.customer_id,
                                     MAX(payments.customer_name) as customer_name,
                                     MAX(payments.customer_email) as customer_email,
                                     COUNT(DISTINCT payments.stripe_id) as transaction_count,
                                     COALESCE(SUM(payments.converted_amount), 0) as total_amount')
                            .group('payments.customer_id')
                            .order('customer_name ASC NULLS LAST, customer_email ASC NULLS LAST')

    # Calculate EU classification summary for each customer
    customers = customers_data.map do |customer_data|
      customer_id = customer_data.customer_id
      transactions = Payment.transactions_for_customer(customer_id, Current.user)
      
      # Get customer-influenced EU classifications from transactions
      classifications = transactions.map do |transaction|
        classification = transaction.customer_influenced_eu_classification
        classification[:customer_influenced].to_s
      end.compact
      
      # Determine most common classification
      eu_classification_summary = if classifications.empty?
        'undetermined'
      else
        classification_counts = classifications.group_by(&:itself).transform_values(&:count)
        most_common = classification_counts.max_by { |_, count| count }&.first
        most_common || 'undetermined'
      end

      # Get primary currency for this customer's payments
      customer_payments = Payment.joins(:payout)
                                 .where(payouts: { user_id: Current.user.id })
                                 .where(customer_id: customer_id)
      primary_currency = customer_payments.where.not(converted_currency: nil)
                                          .first&.converted_currency ||
                         customer_payments.where.not(currency: nil)
                                          .first&.currency ||
                         'USD'

      {
        customer_id: customer_id,
        customer_name: customer_data.customer_name,
        customer_email: customer_data.customer_email,
        transaction_count: transactions.count,
        total_amount: customer_data.total_amount.to_f,
        primary_currency: primary_currency,
        eu_classification_summary: eu_classification_summary
      }
    end

    # Pagination
    page = params[:page]&.to_i || 1
    per_page = 25
    total_count = customers.count
    total_pages = (total_count.to_f / per_page).ceil
    paginated_customers = customers[(page - 1) * per_page, per_page] || []

    render inertia: 'Customers/Index', props: {
      customers: paginated_customers,
      pagination: {
        current_page: page,
        total_pages: total_pages,
        total_count: total_count,
        per_page: per_page
      }
    }
  end

  def show
    customer_id = params[:id]
    
    # Verify customer belongs to current user
    customer_payment = Payment.joins(:payout)
                             .where(payouts: { user_id: Current.user.id })
                             .where(customer_id: customer_id)
                             .first

    unless customer_payment
      redirect_to customers_path, alert: 'Customer not found'
      return
    end

    # Get customer info
    customer_info = {
      customer_id: customer_id,
      customer_name: customer_payment.customer_name,
      customer_email: customer_payment.customer_email
    }

    # Get all transactions for this customer
    transactions = Payment.transactions_for_customer(customer_id, Current.user)
                        .order(created_at_stripe: :desc)

    # Build transaction props with enhanced data
    transaction_props = transactions.map do |transaction|
      enhancement = transaction.enhanced_location_confidence
      classification = transaction.customer_influenced_eu_classification
      
      {
        id: transaction.id,
        transaction_id: transaction.transaction_id,
        created_at_stripe: transaction.created_at_stripe,
        status: transaction.status,
        decline_reason: transaction.decline_reason,
        card_address_country: transaction.card_address_country,
        card_issue_country: transaction.card_issue_country,
        shipping_address_country: transaction.shipping_address_country,
        location_confidence_score: transaction.location_confidence_score,
        enhanced_location_confidence_score: enhancement[:enhanced_score],
        inferred_fields: enhancement[:inferred_fields],
        inferred_data: enhancement[:inferred_data],
        eu_classification: transaction.eu_classification,
        customer_influenced_eu_classification: classification[:customer_influenced],
        has_payment: transaction.payment.present?,
        payment_id: transaction.payment&.id
      }
    end

    # Calculate customer-level summary stats
    # Get payments for these transactions to calculate total amount
    payment_ids = transactions.map { |t| t.payment&.id }.compact
    customer_payments = Payment.where(id: payment_ids)
    total_amount = customer_payments.sum(:converted_amount).to_f
    
    # Get primary currency for this customer's payments
    primary_currency = customer_payments.where.not(converted_currency: nil)
                                      .first&.converted_currency ||
                       customer_payments.where.not(currency: nil)
                                      .first&.currency ||
                       'USD'
    
    eu_count = transactions.where(eu_classification: :eu).count
    non_eu_count = transactions.where(eu_classification: :non_eu).count
    undetermined_count = transactions.where(eu_classification: :undetermined).count

    render inertia: 'Customers/Show', props: {
      customer: customer_info,
      transactions: transaction_props,
      summary: {
        transaction_count: transactions.count,
        total_amount: total_amount,
        primary_currency: primary_currency,
        eu_count: eu_count,
        non_eu_count: non_eu_count,
        undetermined_count: undetermined_count
      }
    }
  end
end

