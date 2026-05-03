require 'csv'

class PayoutCsvParser
  REQUIRED_COLUMNS = %w[Type ID Created Amount Currency Converted\ Amount Fees Net Converted\ Currency].freeze

  attr_reader :csv_content, :errors

  def initialize(csv_content)
    @csv_content = csv_content
    @errors = []
  end

  def parse
    return { success: false, errors: ["CSV content is empty"] } if csv_content.blank?

    begin
      rows = CSV.parse(csv_content, headers: true)
      
      validate_headers(rows.headers)
      return { success: false, errors: errors } if errors.any?

      payments_data = []
      dates = []

      rows.each_with_index do |row, index|
        row_number = index + 2 # +2 because CSV is 1-indexed and we skip header
        
        payment_data = parse_payment_row(row, row_number)
        if payment_data[:error]
          errors << "Row #{row_number}: #{payment_data[:error]}"
        else
          payments_data << payment_data[:data]
          dates << payment_data[:data][:created_at_stripe] if payment_data[:data][:created_at_stripe]
        end
      end

      return { success: false, errors: errors } if errors.any? || payments_data.empty?

      period_start = dates.min&.to_date
      period_end = dates.max&.to_date
      
      # Generate default period name from date range
      period_name = generate_period_name(period_start, period_end)

      {
        success: true,
        payments: payments_data,
        period_start: period_start,
        period_end: period_end,
        period_name: period_name
      }
    rescue CSV::MalformedCSVError => e
      { success: false, errors: ["Invalid CSV format: #{e.message}"] }
    rescue StandardError => e
      { success: false, errors: ["Error parsing CSV: #{e.message}"] }
    end
  end

  private

  def validate_headers(headers)
    missing_columns = REQUIRED_COLUMNS - headers
    if missing_columns.any?
      errors << "Missing required columns: #{missing_columns.join(', ')}"
    end
  end

  def parse_payment_row(row, row_number)
    begin
      type = row['Type']&.strip
      stripe_id = row['ID']&.strip
      created_str = row['Created']&.strip
      description = row['Description']&.strip
      amount_str = row['Amount']&.strip
      currency = row['Currency']&.strip
      converted_amount_str = row['Converted Amount']&.strip
      fees_str = row['Fees']&.strip
      net_str = row['Net']&.strip
      converted_currency = row['Converted Currency']&.strip
      details = row['Details']&.strip
      customer_id = row['Customer ID']&.strip
      customer_email = row['Customer Email']&.strip
      customer_name = row['Customer Name']&.strip

      # Validate required fields
      if type.blank?
        return { error: "Type is required" }
      end
      if stripe_id.blank?
        return { error: "ID is required" }
      end
      if created_str.blank?
        return { error: "Created date is required" }
      end

      # Parse date (format: "2025-10-08 17:36")
      created_at_stripe = parse_datetime(created_str)
      if created_at_stripe.nil?
        return { error: "Invalid Created date format: #{created_str}" }
      end

      # Parse amounts (handle European format with comma as decimal separator)
      amount = parse_decimal(amount_str)
      converted_amount = parse_decimal(converted_amount_str)
      fees = parse_decimal(fees_str)
      net = parse_decimal(net_str)

      # Set EU classification based on type
      eu_classification = if type == "Stripe Fee"
        3 # stripe_fees
      else
        0 # undetermined (default for charges)
      end

      if amount.nil?
        return { error: "Invalid Amount: #{amount_str}" }
      end
      if converted_amount.nil?
        return { error: "Invalid Converted Amount: #{converted_amount_str}" }
      end
      if fees.nil?
        return { error: "Invalid Fees: #{fees_str}" }
      end
      if net.nil?
        return { error: "Invalid Net: #{net_str}" }
      end

      {
        data: {
          type: type,
          stripe_id: stripe_id,
          created_at_stripe: created_at_stripe,
          description: description,
          amount: amount,
          currency: currency,
          converted_amount: converted_amount,
          fees: fees,
          net: net,
          converted_currency: converted_currency,
          details: details,
          customer_id: customer_id,
          customer_email: customer_email,
          customer_name: customer_name,
          eu_classification: eu_classification
        }
      }
    rescue StandardError => e
      { error: "Error parsing row: #{e.message}" }
    end
  end

  def parse_decimal(value)
    return nil if value.blank?

    # Handle European format: "9,99" -> 9.99
    # Also handle negative values: "-0,32" -> -0.32
    normalized = value.to_s.strip.gsub(',', '.')
    
    # Remove any thousand separators (spaces or dots used as thousands)
    normalized = normalized.gsub(/\s+/, '')
    
    BigDecimal(normalized)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_datetime(value)
    return nil if value.blank?

    # Try parsing format: "2025-10-08 17:36"
    DateTime.strptime(value.strip, "%Y-%m-%d %H:%M")
  rescue ArgumentError
    # Try other common formats
    begin
      DateTime.parse(value.strip)
    rescue ArgumentError
      nil
    end
  end

  def generate_period_name(start_date, end_date)
    return "Unknown Period" if start_date.nil? || end_date.nil?

    if start_date.year == end_date.year && start_date.month == end_date.month
      # Same month: "October 2025"
      start_date.strftime("%B %Y")
    elsif start_date.year == end_date.year
      # Same year, different months: "September - October 2025"
      "#{start_date.strftime('%B')} - #{end_date.strftime('%B %Y')}"
    else
      # Different years: "September 2024 - October 2025"
      "#{start_date.strftime('%B %Y')} - #{end_date.strftime('%B %Y')}"
    end
  end
end

