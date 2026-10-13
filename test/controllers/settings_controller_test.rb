require "test_helper"
require "cgi"
require "json"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Sign the fixture user in via the real sessions#create endpoint
    # so the auth concerns sees a real session + Current.user.
    post session_path, params: {
      email_address: users(:one).email_address,
      password: "password"
    }
    @user = users(:one)
    @user.update_columns(stripe_secret_key: nil)
  end

  teardown do
    delete session_path
    @user.update_columns(stripe_secret_key: nil)
  end

  test "GET /settings shows the settings page with stripe_configured=false" do
    get "/settings"

    assert_response :success
    assert_match(/Settings/, response.body)
    props = parse_inertia_props(response.body)
    refute props.dig("user", "stripe_configured")
    assert_nil props.dig("user", "stripe_last4")
    assert_equal SettingsController::STRIPE_PLACEHOLDER, props.dig("user", "stripe_placeholder")
  end

  test "PATCH /settings sets a new Stripe key" do
    assert_nil @user.stripe_secret_key

    patch "/settings", params: { user: { stripe_secret_key: "sk_test_brand_new_key" } }

    @user.reload
    assert_equal "sk_test_brand_new_key", @user.stripe_secret_key
    assert_redirected_to settings_path
  end

  test "PATCH /settings ignores the placeholder value as a no-op" do
    @user.stripe_secret_key = "sk_test_existing"
    @user.save!

    patch "/settings", params: { user: { stripe_secret_key: SettingsController::STRIPE_PLACEHOLDER } }

    # Existing key should NOT be dropped when the user clicks Save
    # without changing the field (the placeholder check).
    assert_equal "sk_test_existing", @user.reload.stripe_secret_key
  end

  test "PATCH /settings replaces an existing Stripe key" do
    @user.stripe_secret_key = "sk_test_existing"
    @user.save!

    patch "/settings", params: { user: { stripe_secret_key: "sk_test_replacement" } }

    assert_equal "sk_test_replacement", @user.reload.stripe_secret_key
  end

  test "DELETE /settings/stripe_secret_key clears the key" do
    @user.stripe_secret_key = "sk_test_to_delete"
    @user.save!

    delete "/settings/stripe_secret_key"

    assert_nil @user.reload.stripe_secret_key
    assert_redirected_to settings_path
  end

  test "GET /settings shows last4 when configured" do
    @user.stripe_secret_key = "sk_test_ends_in_xyz9"
    @user.save!

    get "/settings"

    assert_response :success
    props = parse_inertia_props(response.body)
    assert props.dig("user", "stripe_configured")
    assert_equal "xyz9", props.dig("user", "stripe_last4")
    assert_equal SettingsController::STRIPE_PLACEHOLDER, props.dig("user", "stripe_placeholder")
  end

  private

  # Inertia sends page props as JSON in a `data-page` attribute.
  def parse_inertia_props(html)
    match = html.match(/data-page=(["'])(.*?)\1/)
    return {} unless match

    parsed = JSON.parse(CGI.unescapeHTML(match[2]))
    parsed["props"] || {}
  end
end
