# frozen_string_literal: true

require "prawn"
require "prawn/table"

# Renders a per-payout PDF listing the payments that fall into a given
# classification (:eu, :non_eu, :undetermined, :stripe_fees), together with
# the Danish kontoplan booking entries that the user needs for tax
# reporting.
class PayoutPdfService
  # Mapping of payout classification -> Danish chart-of-accounts (kontoplan)
  # information to render under the "Bogføring" heading. If a
  # classification is not in this map (e.g. :undetermined), the booking
  # section is skipped so we never print misleading bookkeeping info.
  #
  # Each entry is:
  #   rows:       Array<Hash> — one row per ledger posting, with
  #                            :account (4-digit kontonummer),
  #                            :description (kontonavn),
  #                            :side ("Debet" or "Kredit")
  #   salgsmoms:  String|nil — Danish VAT treatment description shown
  #                            beneath the table; nil = omit the line.
  BOOKING_INFO = {
    eu: {
      rows: [
        { account: "1110", description: "Salg",    side: "Kredit" },
        { account: "2320", description: "Gebyrer", side: "Debet"  },
        { account: "5840", description: "Stripe",  side: "Debet"  }
      ],
      salgsmoms: "ydelser i EU 25% salgs moms"
    },
    non_eu: {
      rows: [
        { account: "1110", description: "Salg",    side: "Kredit" },
        { account: "2320", description: "Gebyrer", side: "Debet"  },
        { account: "5840", description: "Stripe",  side: "Debet"  }
      ],
      salgsmoms: "ydelser verden 0% salgs moms"
    },
    stripe_fees: {
      rows: [
        { account: "2320", description: "Gebyrer", side: "Debet"  },
        { account: "2320", description: "Gebyrer", side: "Kredit" }
      ],
      salgsmoms: nil
    }
  }.freeze

  def self.generate(payout, classification_type)
    new(payout, classification_type).generate
  end

  def initialize(payout, classification_type)
    @payout              = payout
    @classification_type = classification_type.to_sym
  end

  def generate
    pdf = Prawn::Document.new(
      page_size: "A4",
      margin:    [ 40, 40, 40, 40 ],
      info:      {
        Title:   pdf_title,
        Author:  "Stripe Tax Reporting",
        Subject: "Payout Tax Report"
      }
    )

    add_header(pdf)
    add_payment_table(pdf)
    add_booking_info(pdf)
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
    when :eu            then "EU"
    when :non_eu        then "Non-EU"
    when :undetermined  then "Undetermined"
    when :stripe_fees   then "Stripe Fees"
    else                     "Unknown"
    end
  end

  def filtered_payments
    @filtered_payments ||= payout.payments.select do |payment|
      payment_classification(payment) == classification_type
    end
  end

  def payment_classification(payment)
    return :stripe_fees if payment.type == "Stripe Fee"

    payment.effective_eu_classification.to_sym
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

    headers = [ "Stripe ID", "Date", "Cntry", "Amount", "Fees", "Net", "Curr" ]

    data = filtered_payments.map do |payment|
      transaction   = payment.stripe_transaction
      country_code  = customer_country_code(transaction)
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

    available_width = pdf.bounds.width
    pdf.table([ headers ] + data,
              header: true,
              width:  available_width) do |table|
      table.row(0).font_style       = :bold
      table.row(0).background_color = "E0E0E0"
      table.row(0).align            = :center
      table.columns(3..5).align     = :right
      table.cells.font_size         = 7
      table.row(0).font_size        = 8
      table.cells.padding           = [ 3, 3, 3, 3 ]
      table.cells.overflow          = :shrink_to_fit
    end

    pdf.move_down 20
  end

  # Bogføring / kontoplan section. Renders the Danish account numbers, names
  # and debit/credit sides the transactions in this PDF are booked to, plus
  # an optional salgsmoms line. Skipped entirely for classifications that
  # have no booking mapping (e.g. :undetermined) so the PDF never shows
  # unverified or misleading bookkeeping info.
  def add_booking_info(pdf)
    info = BOOKING_INFO[classification_type]
    return unless info

    pdf.text "Bogføring", size: 14, style: :bold
    pdf.move_down 10

    headers = [ "Konto", "Beskrivelse", "Debet/Kredit" ]
    rows    = info[:rows].map { |row| [ row[:account], row[:description], row[:side] ] }

    pdf.table([ headers ] + rows, width: 300) do |table|
      table.row(0).font_style       = :bold
      table.row(0).background_color = "E0E0E0"
      table.row(0).align            = :center
      table.columns(0).font_style   = :bold  # bold account numbers
      table.cells.font_size         = 10
      table.cells.padding           = [ 3, 3, 3, 3 ]
    end

    if info[:salgsmoms]
      pdf.move_down 10
      pdf.text "Salgsmoms: #{info[:salgsmoms]}", size: 11
    end

    pdf.move_down 20
  end

  def add_summary(pdf)
    return if filtered_payments.empty?

    pdf.text "Summary", size: 14, style: :bold
    pdf.move_down 10

    total_count  = filtered_payments.count
    total_amount = filtered_payments.sum(&:converted_amount)
    total_fees   = filtered_payments.sum(&:fees)
    total_net    = filtered_payments.sum(&:net)
    currency     = payout.primary_currency

    summary_data = [
      [ "Total Payments",            total_count.to_s ],
      [ "Total Amount (#{currency})", format_amount(total_amount) ],
      [ "Total Fees (#{currency})",   format_amount(total_fees) ],
      [ "Total Net (#{currency})",    format_amount(total_net) ]
    ]

    pdf.table(summary_data, width: 300) do |table|
      table.columns(0).font_style = :bold
      table.columns(1).align      = :right
    end
  end

  def format_amount(amount)
    sprintf("%.2f", amount.to_f)
  end

  def customer_country_code(transaction)
    return nil unless transaction

    enhancement   = transaction.enhanced_location_confidence
    inferred_data = enhancement[:inferred_data] || {}

    transaction.card_address_country ||
      inferred_data[:card_address_country] ||
      transaction.shipping_address_country ||
      inferred_data[:shipping_address_country] ||
      transaction.card_issue_country ||
      inferred_data[:card_issue_country]
  end
end
