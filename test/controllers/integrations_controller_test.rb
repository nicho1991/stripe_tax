require "test_helper"
require "minitest/mock"

class IntegrationsControllerTest < ActionController::TestCase
  setup do
    @user = User.create!(email_address: "tester@example.com", password: "password123")
    session_record = @user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    # ActionController::TestCase#cookies is a real ActionDispatch cookie jar
    # and supports .signed, so we can mimic what Authentication#start_new_session_for
    # does in production.
    cookies.signed[:session_id] = session_record.id
  end

  def inertia_props
    html = @response.body
    match = html.match(/data-page=(["'])(.*?)\1/)
    assert match, "Expected Inertia data-page attribute in response"
    JSON.parse(CGI.unescapeHTML(match[2]))["props"]
  end

  # ------------------------------------------------------------------
  # GET /integrations
  # ------------------------------------------------------------------
  test "GET /integrations renders the Integrations/Index page" do
    get :index
    assert_response :success
    props = inertia_props
    assert_equal false, props["stripe"]["connected"]
    assert_equal false, props["stripe"]["verified"]
    assert_nil props["stripe"]["masked_key"]
  end

  test "GET /integrations reflects an already-saved key" do
    @user.update!(
      stripe_api_key: "rk_test_AbCdEf123456",
      stripe_api_key_prefix: "rk_test_",
      stripe_api_key_last4: "3456",
      stripe_account_id: "acct_999",
      stripe_account_label: "Acme",
      stripe_account_country: "DK",
      stripe_account_default_currency: "dkk",
      stripe_connected_at: Time.current
    )
    get :index
    props = inertia_props
    assert_equal true, props["stripe"]["connected"]
    assert_equal true, props["stripe"]["verified"]
    assert_equal "rk_test_...3456", props["stripe"]["masked_key"]
    assert_equal "acct_999", props["stripe"]["account"]["id"]
    assert_equal "Acme", props["stripe"]["account"]["label"]
  end

  # ------------------------------------------------------------------
  # POST save_stripe
  # ------------------------------------------------------------------
  test "POST save_stripe saves a valid restricted key" do
    post :save_stripe, params: { stripe: { api_key: "rk_test_AbCdEf123456" } }
    assert_redirected_to integrations_path
    @user.reload
    assert_equal "rk_test_AbCdEf123456", @user.stripe_api_key
    assert_equal "rk_test_", @user.stripe_api_key_prefix
    assert_equal "3456", @user.stripe_api_key_last4
  end

  test "POST save_stripe rejects a secret (sk_) key" do
    post :save_stripe, params: { stripe: { api_key: "sk_test_AbCdEf123456" } }
    assert_response :unprocessable_entity
    props = inertia_props
    assert props["errors"]["stripe_api_key"].any? { |m| m.include?("restricted key") }
    assert_nil @user.reload.stripe_api_key
  end

  test "POST save_stripe with a blank key returns an error" do
    post :save_stripe, params: { stripe: { api_key: "" } }
    assert_response :unprocessable_entity
    props = inertia_props
    assert props["errors"]["stripe_api_key"].any? { |m| m.include?("required") }
  end

  # ------------------------------------------------------------------
  # POST test_stripe
  # ------------------------------------------------------------------
  test "POST test_stripe on a working key caches account info" do
    @user.update!(
      stripe_api_key: "rk_test_AbCdEf123456",
      stripe_api_key_prefix: "rk_test_",
      stripe_api_key_last4: "3456"
    )

    fake_account = Struct.new(:id, :business_profile, :settings, :email, :country, :default_currency, :livemode).new(
      "acct_42",
      Struct.new(:name).new("Round Trip Co"),
      Struct.new(:dashboard).new(Struct.new(:display_name).new(nil)),
      "x@x.test",
      "DE",
      "eur",
      false
    )

    accounts = Object.new
    accounts.define_singleton_method(:retrieve) { |*_| fake_account }
    v1 = Object.new
    v1.define_singleton_method(:accounts) { accounts }
    client = Object.new
    client.define_singleton_method(:v1) { v1 }

    StripeConnectionService.stub :build_client, client do
      post :test_stripe
    end

    assert_redirected_to integrations_path
    @user.reload
    assert_equal "acct_42", @user.stripe_account_id
    assert_equal "Round Trip Co", @user.stripe_account_label
    assert_equal "DE", @user.stripe_account_country
    assert_equal "eur", @user.stripe_account_default_currency
  end

  test "POST test_stripe surfaces a friendly error on bad key" do
    @user.update!(stripe_api_key: "rk_test_AbCdEf123456")

    accounts = Object.new
    accounts.define_singleton_method(:retrieve) { |*_| raise Stripe::AuthenticationError.new("Invalid") }
    v1 = Object.new
    v1.define_singleton_method(:accounts) { accounts }
    client = Object.new
    client.define_singleton_method(:v1) { v1 }

    StripeConnectionService.stub :build_client, client do
      post :test_stripe
    end

    assert_redirected_to integrations_path
  end

  # ------------------------------------------------------------------
  # DELETE disconnect_stripe
  # ------------------------------------------------------------------
  test "DELETE disconnect_stripe clears the connection" do
    @user.update!(
      stripe_api_key: "rk_test_AbCdEf123456",
      stripe_api_key_prefix: "rk_test_",
      stripe_api_key_last4: "3456",
      stripe_account_id: "acct_99",
      stripe_account_label: "Acme",
      stripe_account_country: "DK",
      stripe_account_default_currency: "dkk",
      stripe_connected_at: Time.current
    )
    delete :disconnect_stripe
    assert_redirected_to integrations_path
    @user.reload
    assert_nil @user.stripe_api_key
    assert_nil @user.stripe_account_id
    assert_nil @user.stripe_account_label
  end

  # ------------------------------------------------------------------
  # Auth gate
  # ------------------------------------------------------------------
  test "all actions require authentication" do
    cookies.signed[:session_id] = nil
    get :index
    assert_redirected_to new_session_path

    post :save_stripe, params: { stripe: { api_key: "rk_test_AbCdEf123456" } }
    assert_redirected_to new_session_path

    delete :disconnect_stripe
    assert_redirected_to new_session_path

    post :test_stripe
    assert_redirected_to new_session_path
  end
end
