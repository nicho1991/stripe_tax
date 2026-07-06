Rails.application.routes.draw do
  root "home#index"
  get "dashboard", to: "dashboard#index"

  resources :payouts do
    collection do
      # Phase 2 — fetch a payout's data from Stripe directly instead
      # of uploading a CSV. Delegates to `payouts#fetch`.
      post :fetch
    end
    member do
      get :pdf_eu
      get :pdf_non_eu
      get :pdf_undetermined
      get :pdf_stripe_fees
      post :update_payment_country
    end
  end
  resources :transactions, only: [ :index, :show, :new, :create ]
  resources :customers, only: [ :index, :show ]

  resource :session
  resource :registration
  resources :passwords, param: :token
  get "inertia-example", to: "inertia_example#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
