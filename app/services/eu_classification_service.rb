require 'countries'

class EuClassificationService
  def self.classify_country(country_code)
    return nil if country_code.blank?

    country = ISO3166::Country.find_country_by_alpha2(country_code.upcase)
    return nil unless country

    country.in_eu? ? :eu : :non_eu
  end

  def self.calculate_confidence(transaction)
    score = 0
    score += 1 if transaction.card_address_country.present?
    score += 1 if transaction.card_issue_country.present?
    score += 1 if transaction.shipping_address_country.present?
    score
  end

  def self.classify_transaction(transaction)
    countries = []
    countries << transaction.card_address_country if transaction.card_address_country.present?
    countries << transaction.card_issue_country if transaction.card_issue_country.present?
    countries << transaction.shipping_address_country if transaction.shipping_address_country.present?

    return :undetermined if countries.empty?

    classifications = countries.map { |code| classify_country(code) }.compact.uniq

    return :undetermined if classifications.empty?

    # If all countries are EU, classify as EU
    return :eu if classifications.all? { |c| c == :eu }

    # If all countries are non-EU, classify as non-EU
    return :non_eu if classifications.all? { |c| c == :non_eu }

    # Mixed or conflicting → undetermined
    :undetermined
  end
end

