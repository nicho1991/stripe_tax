require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module StripeTax
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Ensure services directory is autoloaded
    config.autoload_paths << Rails.root.join("app", "services")

    # Active Record encryption keys.
    # Resolution order:
    #   1. ENV vars (production / CI)
    #   2. .encryption_keys file in the repo root (development / test, gitignored)
    #   3. Rails credentials (production fallback)
    # Generate new keys with: bin/rails db:encryption:init
    encryption_keys_source = if ENV["AR_ENCRYPTION_PRIMARY_KEY"].present?
      {
        primary_key: ENV["AR_ENCRYPTION_PRIMARY_KEY"],
        deterministic_key: ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"],
        key_derivation_salt: ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
      }
    elsif File.exist?(Rails.root.join(".encryption_keys"))
      YAML.load_file(Rails.root.join(".encryption_keys")).symbolize_keys
    else
      Rails.application.credentials.dig(:active_record_encryption)&.symbolize_keys || {}
    end

    config.active_record.encryption.primary_key = encryption_keys_source[:primary_key]
    config.active_record.encryption.deterministic_key = encryption_keys_source[:deterministic_key]
    config.active_record.encryption.key_derivation_salt = encryption_keys_source[:key_derivation_salt]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
