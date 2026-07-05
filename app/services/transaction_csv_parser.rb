class TransactionCsvParser
  attr_reader :csv_content, :errors

  def initialize(csv_content)
    @csv_content = csv_content
    @errors = []
  end

  def parse
    return { success: false, errors: [ "CSV content is empty" ] } if csv_content.blank?

    begin
      require "csv"
      rows = CSV.parse(csv_content, headers: true)

      return { success: false, errors: [ "CSV has no headers" ] } if rows.headers.nil?

      transactions_data = []

      rows.each_with_index do |row, index|
        row_number = index + 2 # +2 because CSV is 1-indexed and we skip header

        transaction_data = parse_transaction_row(row, row_number)
        if transaction_data[:error]
          errors << "Row #{row_number}: #{transaction_data[:error]}"
        elsif transaction_data[:data]
          transactions_data << transaction_data[:data]
        end
        # If transaction_data[:skip] is true, we just skip silently (declined, canceled, etc.)
      end

      return { success: false, errors: errors } if errors.any? && transactions_data.empty?

      {
        success: true,
        transactions: transactions_data,
        errors: errors
      }
    rescue CSV::MalformedCSVError => e
      { success: false, errors: [ "Invalid CSV format: #{e.message}" ] }
    rescue StandardError => e
      { success: false, errors: [ "Error parsing CSV: #{e.message}" ] }
    end
  end

  private

  def parse_transaction_row(row, row_number)
    begin
      transaction_id = row["id"]&.strip
      created_str = row["Created date (UTC)"]&.strip
      status = row["Status"]&.strip
      decline_reason = row["Decline Reason"]&.strip
      card_address_country = row["Card Address Country"]&.strip
      card_issue_country = row["Card Issue Country"]&.strip
      shipping_address_country = row["Shipping Address Country"]&.strip

      # Skip if no transaction ID
      if transaction_id.blank?
        return { skip: true }
      end

      # Skip declined, canceled, or failed transactions
      if status.present? && [ "Failed", "canceled" ].include?(status)
        return { skip: true }
      end

      # Parse date
      created_at_stripe = parse_datetime(created_str)
      if created_at_stripe.nil? && created_str.present?
        return { error: "Invalid Created date format: #{created_str}" }
      end

      # Store all CSV fields in raw_data
      raw_data = {}
      row.headers.each do |header|
        raw_data[header] = row[header]
      end

      {
        data: {
          transaction_id: transaction_id,
          created_at_stripe: created_at_stripe,
          status: status,
          decline_reason: decline_reason,
          card_address_country: card_address_country,
          card_issue_country: card_issue_country,
          shipping_address_country: shipping_address_country,
          raw_data: raw_data
        }
      }
    rescue StandardError => e
      { error: "Error parsing row: #{e.message}" }
    end
  end

  def parse_datetime(value)
    return nil if value.blank?

    # Try parsing format: "2025-11-05 10:20:12"
    DateTime.strptime(value.strip, "%Y-%m-%d %H:%M:%S")
  rescue ArgumentError
    # Try format without seconds: "2025-11-05 10:20"
    begin
      DateTime.strptime(value.strip, "%Y-%m-%d %H:%M")
    rescue ArgumentError
      # Try other common formats
      begin
        DateTime.parse(value.strip)
      rescue ArgumentError
        nil
      end
    end
  end
end
