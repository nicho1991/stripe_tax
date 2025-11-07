class HomeController < ApplicationController
  allow_unauthenticated_access only: %i[ index ]
  
  def index
    if authenticated?
      redirect_to dashboard_path
    end
  end
end

