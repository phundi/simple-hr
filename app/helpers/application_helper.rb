module ApplicationHelper
  def can_render?(perm)
    current_user&.can?(perm)
  end

  def money(amount, company: nil)
    symbol = company&.currency_symbol.presence || "MK"
    value = amount || 0
    value = value.to_d
    precision = value.frac.zero? ? 0 : 2

    "#{symbol} #{number_with_precision(value, precision: precision, delimiter: ",", separator: ".")}"
  end

  def company_url_for(company, path: "/dashboard")
    normalized_path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
    main_domain = ConfigService.get(nil, nil, "main_domain").presence || "hr.com"

    if company&.subdomain == "demo"
      "https://demo.#{main_domain}#{normalized_path}"
    else
      "https://#{main_domain}#{normalized_path}"
    end
  end

  def current_company_url(path = "/dashboard")
    company_url_for(@current_company, path: path)
  end

  def favicon_url
    if @current_company&.logo&.attached?
      url_for(@current_company.logo.variant(resize_to_limit: [ 32, 32 ]))
    elsif @current_company&.logo_url.present?
      @current_company.logo_url
    else
      "/icon.png"
    end
  end
end
