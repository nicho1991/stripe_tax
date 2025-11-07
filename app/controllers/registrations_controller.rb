class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_url, alert: "Try again later." }

  def new
  end

  def create
    @user = User.new(params.permit(:email_address, :password, :password_confirmation))

    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Account created successfully."
    else
      redirect_to new_registration_path, alert: @user.errors.full_messages.to_sentence
    end
  end
end
