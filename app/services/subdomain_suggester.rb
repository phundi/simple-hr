class SubdomainSuggester
  def self.call(company_name)
    new(company_name).call
  end

  def initialize(company_name)
    @company_name = company_name.to_s
  end

  def call
    base = @company_name.parameterize
    base = "company" if base.blank?

    suggestions = [
      base,
      base.split("-").first,
      "#{base}-hr",
      "#{base}-mw"
    ].uniq.first(3)

    suggestions.reject do |suggestion|
      Company.exists?(subdomain: suggestion)
    end
  end
end
