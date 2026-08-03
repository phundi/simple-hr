class ApplicationMailer < ActionMailer::Base
  default from: -> { mailer_from }
  layout "mailer"

  private

  def mailer_from
    app_name = ConfigService.get(nil, nil, "app_name").presence || "PayslipPro"
    support_email = ConfigService.get(nil, nil, "support_email").presence || "support@hr.com"
    "#{app_name} <#{support_email}>"
  end

  def default_url_options
    main_domain = ConfigService.get(nil, nil, "main_domain").presence || "hr.com"
    company = params[:company] || params[:user]&.company
    host = company&.subdomain.present? ? "#{company.subdomain}.#{main_domain}" : main_domain

    { host: host, protocol: "https" }
  end
end
