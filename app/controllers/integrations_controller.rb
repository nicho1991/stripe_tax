class IntegrationsController < ApplicationController
  def index
    render inertia: "Integrations/Index", props: integrations_props
  end

  def save_stripe
    api_key = params.dig(:stripe, :api_key).to_s.strip

    if api_key.blank?
      return render inertia: "Integrations/Index", props: integrations_props(
        errors: { stripe_api_key: [ "API key is required" ] }
      ), status: :unprocessable_entity
    end

    Current.user.assign_attributes(
      stripe_api_key: api_key,
      stripe_api_key_prefix: api_key.match?(User::STRIPE_KEY_PREFIX_REGEX) ? api_key.match(User::STRIPE_KEY_PREFIX_REGEX)[0] : nil,
      stripe_api_key_last4: api_key[-4..]
    )

    if Current.user.save
      redirect_to integrations_path, notice: "Stripe API key saved. Click 'Test Connection' to verify it works."
    else
      render inertia: "Integrations/Index", props: integrations_props(
        errors: Current.user.errors.to_hash
      ), status: :unprocessable_entity
    end
  end

  def disconnect_stripe
    Current.user.clear_stripe_connection!
    redirect_to integrations_path, notice: "Stripe connection removed."
  end

  def test_stripe
    result = StripeConnectionService.test_connection(Current.user)

    if result[:ok]
      redirect_to integrations_path, notice: "Connection works! Connected to #{result[:account][:label] || result[:account][:account_id]}."
    else
      redirect_to integrations_path, alert: result[:error]
    end
  end

  private

  def integrations_props(errors: nil)
    {
      stripe: {
        connected: Current.user.stripe_connected?,
        verified: Current.user.stripe_account_verified?,
        masked_key: Current.user.stripe_masked_key,
        account: {
          id: Current.user.stripe_account_id,
          label: Current.user.stripe_account_label,
          country: Current.user.stripe_account_country,
          default_currency: Current.user.stripe_account_default_currency
        },
        connected_at: Current.user.stripe_connected_at
      },
      errors: errors
    }
  end
end
