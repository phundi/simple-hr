Rails.application.routes.draw do
  main_domain = ConfigService.get(nil, nil, "main_domain").presence || "hr.com"
  non_subdomain_host = lambda do |req|
    host = req.host.to_s.downcase
    host == main_domain || host.include?("localhost")
  end

  devise_for :users, skip: [ :registrations ], controllers: { sessions: "users/sessions" }
  devise_scope :user do
    post "/users/demo_sign_in", to: "users/sessions#demo_sign_in", as: :demo_sign_in
    post "/users/demo_sign_in", to: "users/sessions#demo_sign_in", as: :users_demo_sign_in
  end

  get "/signup", to: "companies#new", as: :signup
  get "/companies/new", to: "companies#new", as: :new_company
  get "/demo-login", to: "companies#demo_login", as: :demo_login
  get "/companies/suggest_subdomain", to: "companies#suggest_subdomain"
  post "companies/cancel", to: "companies#cancel", as: :cancel_company_setup

  resources :companies, only: [ :create ] do
    member do
      get :setup_step1
      post :setup_step1
      get :setup_step2
      post :setup_step2
      get :setup_step3
      post :setup_step3
    end

    collection do
      get :setup
    end
  end

  resources :system_configs, only: [ :index, :update ]
  resources :system_settings, only: [ :index, :update ]
  get "/super_admin/dashboard", to: "super_admin#index", as: :super_admin_dashboard
  get "/super_admin/companies", to: "super_admin#index", as: :super_admin_companies
  post "/super_admin/companies/:company_id/impersonate", to: "super_admin#impersonate", as: :impersonate_super_admin_company
  post "/super_admin/stop_impersonating", to: "super_admin#stop_impersonating", as: :super_admin_stop_impersonating
  resources :company_configs, only: [ :index, :update ] do
    collection do
      patch :update_theme
      post :update_permissions
      post :create_property
      post :update_theme
      patch :update_payroll_settings
      post :update_payroll_components
      post :create_payroll_component
      patch 'update_payroll_component/:id', to: 'company_configs#update_payroll_component', as: :update_payroll_component
      post 'toggle_payroll_component/:id', to: 'company_configs#toggle_payroll_component', as: :toggle_payroll_component
      delete :destroy_component
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

  resources :payroll_imports, only: [:new, :create] do
    collection do
      get :mapping
      get :preview
      post :import
      get :download_template
    end
  end

  resources :employees do
    resource :payroll, only: [:show, :update], controller: 'employee_payrolls' do
      member do
        get :payslip_pdf
        post :email_payslip
      end
    end

    collection do
      post :calculate_preview
      post :bulk_action
    end
    member do
      patch :block
      patch :unblock
    end
  end

  resources :payslips, only: [] do
    member do
      get :pdf
      post :email
      patch :update
    end
  end

  resources :pay_periods do
    member do
      post :publish
      get :export_bank_schedule
      get :export_paye
      get :export_pension
      get :export_tevet
      get :export_funeral
      get :export_medical
      get :export_deductions
      get :export_journal
      post :export_reports
    end
  end

  namespace :admin do
    resources :permissions, only: [ :index ] do
      collection do
        post :update
      end
    end
  end

  get "reports/bank_payment_schedule", to: "bank_payment_schedule#export", as: :bank_payment_schedule_report

  get "dashboard", to: redirect("/")
  get "/company_dashboard", to: "dashboard#index", as: :company_dashboard
  get "payroll", to: redirect("/pay_periods"), as: :payroll
  get "settings", to: "pages#settings"

  unauthenticated do
    root to: redirect("/users/sign_in"), as: :unauthenticated_root
  end

  authenticated :user do
    root to: "dashboard#smart", as: :authenticated_root
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
