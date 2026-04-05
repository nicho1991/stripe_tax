# Ensure prawn-table is loaded before using table methods
require "prawn"
require "prawn/table"

class PayoutPdfService
  def self.generate(payout, classification_type)
    new(payout, classification_type).generate
  end

  def initialize(payout, classification_type)
    @payout = payout
    @classification_type = classification_type.to_sym
  end

  def generate
    # Ensure prawn-table is loaded (safety check)
    require "prawn/table" unless Prawn::Document.instance_methods.include?(:table)

    pdf = Prawn::Document.new(
      page_size: "A4",
      margin: [ 40, 40, 40, 40 ],
      info: {
        Title: pdf_title,
        Author: "Stripe Tax Reporting",
        Subject: "Payout Tax Report"
      }
    )

    add_header(pdf)
    add_payment_table(pdf)
    add_summary(pdf)

    pdf.render
  end

  private

  attr_reader :payout, :classification_type

  def pdf_title
    "#{payout.name} - #{classification_label} Payments"
  end

  def classification_label
    case classification_type
    when :eu
      "EU"
    when :non_eu
      "Non-EU"
    when :undetermined
      "Undetermined"
    when :stripe_fees
      "Stripe Fees"
    else
      "Unknown"
    end
  end

  def filtered_payments
    @filtered_payments ||= payout.payments.select do |payment|
      payment_classification(payment) == classification_type
    end
  end

  def payment_classification(payment)
    return :stripe_fees if payment.type == "Stripe Fee"

    transaction = payment.stripe_transaction
    if transaction
      classification_result = transaction.customer_influenced_eu_classification
      classification_result[:customer_influenced].to_sym
    else
      payment.eu_classification.to_sym
    end
  end

  def add_header(pdf)
    pdf.text pdf_title, size: 20, style: :bold
    pdf.move_down 10

    pdf.text "Payout Period: #{payout.period_start} to #{payout.period_end}", size: 12
    pdf.text "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}", size: 10, style: :italic
    pdf.move_down 20
  end

  def add_payment_table(pdf)
    return pdf.text("No payments found for this classification.", size: 12) if filtered_payments.empty?

    pdf.text "Payment Details", size: 14, style: :bold
    pdf.move_down 10

    # Table headers
    headers = [
      "Stripe ID",
      "Date",
      "Cntry",
      "Amount",
      "Fees",
      "Net",
      "Curr"
    ]

    # Table data
    data = filtered_payments.map do |payment|
      transaction = payment.stripe_transaction
      country_code = customer_country_code(transaction)
      [
        payment.stripe_id,
        payment.created_at_stripe.strftime("%Y-%m-%d"),
        country_code || "N/A",
        format_amount(payment.converted_amount),
        format_amount(payment.fees),
        format_amount(payment.net),
        payment.converted_currency || payment.currency || "N/A"
      ]
    end

    # Create table with auto-sizing columns
    # Calculate available width and distribute proportionally
    available_width = pdf.bounds.width
    pdf.table([ headers ] + data,
              header: true,
              width: available_width) do |table|
      table.row(0).font_style = :bold
      table.row(0).background_color = "E0E0E0"
      table.row(0).align = :center
      table.columns(3..5).align = :right
      table.cells.font_size = 7
      table.row(0).font_size = 8
      table.cells.padding = [ 3, 3, 3, 3 ]
      # Allow text to wrap in cells
      table.cells.overflow = :shrink_to_fit
    end

    pdf.move_down 20
  end

  def add_summary(pdf)
    return if filtered_payments.empty?

    pdf.text "Summary", size: 14, style: :bold
    pdf.move_down 10

    total_count = filtered_payments.count
    total_amount = filtered_payments.sum(&:converted_amount)
    total_fees = filtered_payments.sum(&:fees)
    total_net = filtered_payments.sum(&:net)
    currency = payout.primary_currency

    summary_data = [
      [ "Total Payments", total_count.to_s ],
      [ "Total Amount (#{currency})", format_amount(total_amount) ],
      [ "Total Fees (#{currency})", format_amount(total_fees) ],
      [ "Total Net (#{currency})", format_amount(total_net) ]
    ]

    pdf.table(summary_data, width: 300) do |table|
      table.columns(0).font_style = :bold
      table.columns(1).align = :right
    end
  end

  def format_amount(amount)
    sprintf("%.2f", amount.to_f)
  end

  def customer_country_code(transaction)
    return nil unless transaction

    # Get enhanced location data with inferred country from customer's other transactions
    enhancement = transaction.enhanced_location_confidence
    inferred_data = enhancement[:inferred_data] || {}

    # Prefer card_address_country as it's most relevant for tax purposes
    # Fall back to shipping_address_country, then card_issue_country
    # Check direct transaction fields first, then inferred data
    transaction.card_address_country ||
      inferred_data[:card_address_country] ||
      transaction.shipping_address_country ||
      inferred_data[:shipping_address_country] ||
      transaction.card_issue_country ||
      inferred_data[:card_issue_country]
  end
end
