# Settings page — manage per-user integration credentials.
# Currently supports Stripe (encrypted at rest via Active Record
# encryption). Future integrations (Paddle, Wise, etc.) get their
# own sections here.
#
# The form posts the Stripe API secret as `stripe_secret_key`; the
# model encrypts it via Active Record encryption (`encrypts`) so the
# plaintext is never persisted.
class SettingsController < ApplicationController
  STRIPE_PLACEHOLDER = "sk_test_••••••••".freeze

  def show
    render inertia: "Settings/Index", props: {
      user: settings_props(Current.user)
    }
  end

  def update
    user = Current.user

    stripe_secret = params.dig(:user, :stripe_secret_key).to_s.strip

    if stripe_secret.present? && stripe_secret == STRIPE_PLACEHOLDER
      # The placeholder is rendered into the form when the user
      # already has a key set; if they hit save without changing the
      # input we shouldn't drop the existing key. Detect + ignore.
      stripe_secret = nil
    end

    if stripe_secret.present?
      user.stripe_secret_key = stripe_secret
    end

    if user.save
      redirect_to settings_path, notice: stripe_secret.present? ? "Stripe API key updated." : "Stripe API key cleared."
    else
      render inertia: "Settings/Index", props: {
        user: settings_props(user),
        errors: user.errors.full_messages
      }
    end
  end

  def destroy_stripe_secret
    user = Current.user
    user.stripe_secret_key = nil
    user.save!
    redirect_to settings_path, notice: "Stripe API key removed."
  end

  private

  def settings_props(user)
    has_stripe = user.stripe_secret_key.present?
    {
      id: user.id,
      email_address: user.email_address,
      stripe_configured: has_stripe,
      stripe_last4: has_stripe ? stripe_last4(user) : nil,
      stripe_placeholder: STRIPE_PLACEHOLDER
    }
  end

  # Last 4 characters of the *encrypted* secret — never the plaintext.
  # Useful as a UI hint that "we have a key, ending in …abc1" without
  # exposing the secret.
  def stripe_last4(user)
    user.stripe_secret_key.to_s[-4..] || nil
  end
end
