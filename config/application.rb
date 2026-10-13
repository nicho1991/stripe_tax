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

    # Load Active Record encryption keys from a local, gitignored
    # `.encryption_keys` file if present (each line is
    # `KEY=value`). This is the dev/CI bootstrap path — production
    # should populate via `bin/rails db:encryption:init` writing
    # into config/credentials.yml.enc.
    enc_keys_path = Rails.root.join(".encryption_keys")
    if File.exist?(enc_keys_path)
      File.foreach(enc_keys_path) do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")
        key, value = line.split("=", 2)
        ENV[key] ||= value if key && value
      end
    end

    # Active Record encryption — used to encrypt at rest the per-user
    # `User#stripe_secret_key` column. Per-user Stripe API keys are
    # sensitive, so they live in DB encrypted rather than plaintext.
    #
    # Resolution priority:
    #   1. ENV: ACTIVE_RECORD_ENCRYPTION_{PRIMARY_KEY,DETERMINISTIC_KEY,KEY_DERIVATION_SALT}
    #      (set from .encryption_keys above; or via real env in CI)
    #   2. Rails.application.credentials.dig(:active_record_encryption, <key>)
    #      (production path — populate via `bin/rails db:encryption:init`
    #      once config/master.key is committed)
    [ :primary_key, :deterministic_key, :key_derivation_salt ].each do |k|
      env = ENV["ACTIVE_RECORD_ENCRYPTION_#{k.to_s.upcase}"]
      cred = Rails.application.credentials.dig(:active_record_encryption, k)
      config.active_record.encryption.public_send("#{k}=", env.presence || cred)
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
