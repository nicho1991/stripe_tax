class TransactionsController < ApplicationController
  def index
    transactions = Current.user.transactions.order(created_at_stripe: :desc)
    
    # Filter by EU classification if provided
    if params[:eu_classification].present?
      transactions = transactions.where(eu_classification: params[:eu_classification])
    end

    render inertia: 'Transactions/Index', props: {
      transactions: transactions.map { |t| transaction_props(t) },
      filters: {
        eu_classification: params[:eu_classification]
      }
    }
  end

  def show
    transaction = Current.user.transactions.find_by(transaction_id: params[:id]) || 
                  Current.user.transactions.find_by(id: params[:id])
    
    unless transaction
      redirect_to transactions_path, alert: 'Transaction not found'
      return
    end

    render inertia: 'Transactions/Show', props: {
      transaction: transaction_props(transaction),
      payment: transaction.payment ? payment_props(transaction.payment) : nil
    }
  end

  def new
    render inertia: 'Transactions/New'
  end

  def create
    csv_file = params[:csv_file]

    if csv_file.blank?
      return render inertia: 'Transactions/New', props: {
        errors: { csv_file: ['CSV file is required'] }
      }
    end

    # Read CSV content with UTF-8 encoding
    csv_content = csv_file.read.force_encoding('UTF-8')
    csv_file.rewind

    # Parse CSV
    parser = ::TransactionCsvParser.new(csv_content)
    result = parser.parse

    unless result[:success]
      return render inertia: 'Transactions/New', props: {
        errors: { base: result[:errors] }
      }
    end

    # Import transactions
    import_service = TransactionImportService.new(Current.user)
    import_result = import_service.import(result[:transactions])

    if import_result[:errors].any?
      return render inertia: 'Transactions/New', props: {
        errors: { base: import_result[:errors] },
        warnings: import_result[:warnings]
      }
    end

    # Build success message
    notice = "Imported #{import_result[:imported]} transaction(s)"
    notice += ", skipped #{import_result[:skipped]} duplicate(s)" if import_result[:skipped] > 0
    
    if import_result[:warnings].any?
      flash[:warnings] = import_result[:warnings]
    end

    redirect_to transactions_path, notice: notice
  rescue StandardError => e
    render inertia: 'Transactions/New', props: {
      errors: { base: ["An error occurred: #{e.message}"] }
    }
  end

  private

  def transaction_props(transaction)
    customer_id = transaction.payment&.customer_id
    customer_link = customer_id.present? ? customer_path(customer_id) : nil
    payment = transaction.payment

    {
      id: transaction.id,
      transaction_id: transaction.transaction_id,
      created_at_stripe: transaction.created_at_stripe,
      status: transaction.status,
      decline_reason: transaction.decline_reason,
      location_confidence_score: transaction.location_confidence_score,
      eu_classification: transaction.eu_classification,
      has_payment: transaction.payment.present?,
      payment_id: transaction.payment&.id,
      customer_id: customer_id,
      customer_link: customer_link,
      amount: payment ? payment.converted_amount.to_f : nil,
      fees: payment ? payment.fees.to_f : nil,
      currency: payment ? (payment.converted_currency || payment.currency) : nil,
      raw_data: transaction.raw_data
    }
  end

  def payment_props(payment)
    customer_link = payment.customer_id.present? ? customer_path(payment.customer_id) : nil

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
      eu_classification: payment.eu_classification,
      payout_id: payment.payout_id
    }
  end
end

