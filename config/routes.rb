Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ]

  resources :companies, only: [ :new, :create ] do
    collection do
      get :setup
      get :suggest_subdomain
    end
  end

  resources :system_configs, only: [ :index, :update ]
  resources :company_configs, only: [ :index, :update ] do
    collection do
      post :create_property
      delete :destroy_property
    end
  end

  get "onboarding/:token", to: "onboarding#show", as: :onboarding
  patch "onboarding/:token", to: "onboarding#update"

  resources :import_templates, only: [ :new, :create ] do
    collection do
      get :download_sample
    end

    member do
      get :preview
      post :import
    end
  end

  resources :users do
    collection do
      get :account
      patch :update_account
    end

    member do
      patch :block
      patch :unblock
      post :resend_invite
    end
  end

  resources :employees do
    member do
      patch :block
      patch :unblock
    end
  end

  get "reports/bank_payment_schedule", to: "bank_payment_schedule#export", as: :bank_payment_schedule_report

  get "dashboard", to: "dashboard#index"
  get "payroll", to: "pages#payroll"
  get "settings", to: "pages#settings"

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  unauthenticated do
    root to: redirect("/users/sign_in"), as: :unauthenticated_root
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
