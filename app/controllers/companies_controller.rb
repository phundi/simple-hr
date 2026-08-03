class CompaniesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :setup, :setup_step1, :setup_step2, :setup_step3, :create, :cancel, :suggest_subdomain, :demo_login ]
  before_action :load_wizard_state, only: [ :setup, :create, :setup_step1, :setup_step2, :setup_step3, :cancel ]

  def new
    redirect_to setup_step1_company_path(company_for_wizard_route)
  end

  def setup_step1
    @step = 1
    @suggestions = SubdomainSuggester.call(@wizard_name.presence || "Company")
    return render :setup_step1 unless request.post?

    name = wizard_params[:name].to_s.strip
    subdomain = wizard_params[:subdomain].to_s.strip.downcase

    if name.blank? || subdomain.blank?
      @wizard_name = name
      @wizard_subdomain = subdomain
      @suggestions = SubdomainSuggester.call(name.presence || "Company")
      flash.now[:alert] = "Company name and subdomain are required."
      render :setup_step1, status: :unprocessable_entity
      return
    end

    session[:company_wizard] ||= {}
    session[:company_wizard].merge!(
      "name" => name,
      "subdomain" => subdomain
    )

    redirect_to setup_step2_company_path(@wizard_company)
  end

  def setup_step2
    @step = 2
    return render :setup_step2 unless request.post?

    session[:company_wizard] ||= {}
    session[:company_wizard]["primary_color"] = wizard_params[:primary_color].presence || "#0d6efd"
    session[:company_wizard]["logo_signed_id"] = upload_logo_signed_id || wizard_params[:logo_signed_id]

    redirect_to setup_step3_company_path(@wizard_company)
  end

  def setup_step3
    @step = 3
    if request.post?
      session[:company_wizard] ||= {}
      session[:company_wizard].merge!(
        "admin_first_name" => wizard_params[:admin_first_name].to_s.strip,
        "admin_last_name" => wizard_params[:admin_last_name].to_s.strip,
        "admin_email" => wizard_params[:admin_email].to_s.strip.downcase,
        "admin_password" => wizard_params[:admin_password].to_s
      )
      load_wizard_state
    end

    render :setup_step3
  end

  def setup
    @step = normalized_step
    @suggestions = SubdomainSuggester.call(@wizard_name.presence || "Company") if @step == 1
  end

  def suggest_subdomain
    render json: { suggestions: SubdomainSuggester.new(params[:name]).call }
  end

  def demo_login
    company = Company.find_by(subdomain: "demo")
    if company.blank?
      Rake::Task["db:seed"].reenable
      Rake::Task["db:seed"].invoke
      company = Company.find_by(subdomain: "demo")
    end

    user = User.find_by(email: "admin@demo.com")
    if company.blank? || user.blank?
      redirect_to new_user_session_path, alert: "Demo setup is unavailable right now. Please run db:seed." and return
    end

    sign_in(user)
    session[:company_id] = company.id
    redirect_to "https://demo.#{ConfigService.get(nil,nil,'main_domain')}/dashboard", notice: "Demo data resets on each seed", allow_other_host: true
  end

  def create
    session[:company_wizard] ||= {}
    session[:company_wizard].merge!(
      "admin_first_name" => wizard_params[:admin_first_name].to_s.strip,
      "admin_last_name" => wizard_params[:admin_last_name].to_s.strip,
      "admin_email" => wizard_params[:admin_email].to_s.strip.downcase,
      "admin_password" => wizard_params[:admin_password].to_s
    )

    create_company_from_wizard
  end

  def cancel
    session.delete(:company_wizard)
    redirect_to new_user_session_path, alert: "Company setup cancelled"
  end

  private

  def normalized_step
    raw = params[:step].to_i
    return 1 if raw < 1
    return 3 if raw > 3

    raw
  end

  def load_wizard_state
    wizard_state = session[:company_wizard] || {}
    @wizard_company = Company.find_by(id: params[:id]) || company_for_wizard_route

    @wizard_name = wizard_state["name"]
    @wizard_subdomain = wizard_state["subdomain"]
    @wizard_primary_color = wizard_state["primary_color"] || "#0d6efd"
    @wizard_logo_signed_id = wizard_state["logo_signed_id"]
    @admin_first_name = wizard_state["admin_first_name"]
    @admin_last_name = wizard_state["admin_last_name"]
    @admin_email = wizard_state["admin_email"]

    @wizard_step1_complete = @wizard_name.present? && @wizard_subdomain.present?
    @wizard_step2_complete = wizard_state.key?("primary_color") || @wizard_logo_signed_id.present?
  end

  def wizard_params
    params.fetch(:company, {}).permit(
      :name,
      :subdomain,
      :primary_color,
      :logo_signed_id,
      :logo,
      :admin_first_name,
      :admin_last_name,
      :admin_email,
      :admin_password
    )
  end

  def upload_logo_signed_id
    upload = wizard_params[:logo]
    return nil unless upload

    blob = ActiveStorage::Blob.create_and_upload!(
      io: upload.tempfile,
      filename: upload.original_filename,
      content_type: upload.content_type
    )

    blob.signed_id
  end

  def company_for_wizard_route
    current_user&.company || default_company
  end

  def create_company_from_wizard
    data = session[:company_wizard] || {}
    admin_first_name = data["admin_first_name"].to_s.strip
    admin_last_name = data["admin_last_name"].to_s.strip
    admin_email = data["admin_email"].to_s.strip.downcase
    admin_password = data["admin_password"].to_s

    @admin_first_name = admin_first_name
    @admin_last_name = admin_last_name
    @admin_email = admin_email

    if data["name"].to_s.strip.blank? || data["subdomain"].to_s.strip.blank?
      redirect_to setup_step3_company_path(@wizard_company), alert: "Company name and subdomain are required."
      return
    end

    if [ admin_first_name, admin_last_name, admin_email, admin_password ].any?(&:blank?)
      redirect_to setup_step3_company_path(@wizard_company), alert: "Admin first name, last name, email, and password are required."
      return
    end

    @company = Company.new(
      name: data["name"],
      subdomain: data["subdomain"],
      primary_color: data["primary_color"].presence || "#206bc4"
    )

    if data["logo_signed_id"].present?
      blob = ActiveStorage::Blob.find_signed(data["logo_signed_id"])
      @company.logo.attach(blob)
    end

    admin_user = @company.users.build(
      first_name: admin_first_name,
      last_name: admin_last_name,
      email: admin_email,
      password: admin_password,
      password_confirmation: admin_password,
      role: :admin,
      status: :active,
      onboarding_status: :verified
    )

    property_records = build_required_company_properties(@company)

    validation_errors = []
    validation_errors.concat(@company.errors.full_messages) unless @company.valid?
    validation_errors.concat(admin_user.errors.full_messages) unless admin_user.valid?
    property_records.each do |record|
      validation_errors.concat(record.errors.full_messages) unless record.valid?
    end

    if validation_errors.any?
      redirect_to setup_step3_company_path(@wizard_company), alert: validation_errors.uniq.to_sentence
      return
    end

    ActiveRecord::Base.transaction do
      @company.save!
      property_records.each(&:save!)
      admin_user.save!
    end

    session.delete(:company_wizard)
    sign_in(admin_user)
    session[:company_id] = @company.id
    if ConfigService.get(nil, nil, "enable_subdomain_redirect").to_s == "true"
      domain = ConfigService.get(nil, nil, "main_domain").presence || main_domain
      redirect_to "https://#{@company.subdomain}.#{domain}/dashboard", notice: "Welcome to PayslipPro", allow_other_host: true
    else
      redirect_to authenticated_root_path, notice: "Welcome to PayslipPro"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to setup_step3_company_path(@wizard_company), alert: e.record.errors.full_messages.to_sentence.presence || "Could not complete setup."
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to setup_step3_company_path(@wizard_company), alert: "Uploaded logo could not be verified. Please upload it again."
  end

  def build_required_company_properties(company)
    CompanyProperty::PROPERTY_KEYS.map.with_index do |key, index|
      company.company_properties.find_or_initialize_by(property_key: key, value: key.humanize).tap do |prop|
        prop.position = index
      end
    end
  end

  def step_three_template
    :setup_step3
  end

  def onboarding_dashboard_url(subdomain)
    domain = ConfigService.get(nil, nil, "main_domain").presence || main_domain
    "https://#{subdomain}.#{domain}/dashboard"
  end
end
