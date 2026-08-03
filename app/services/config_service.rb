class ConfigService
  def self.get(user, company, key)
    key = key.to_s

    user_value = user_config_value(user, key)
    return user_value unless user_value.nil?

    company_value = company_config_value(company, key)
    return company_value unless company_value.nil?

    system_config_value(key)
  end

  class << self
    private

    def user_config_value(user, key)
      return nil unless user

      user.user_configs.find_by(key: key)&.value
    end

    def company_config_value(company, key)
      return nil unless company

      company.company_configs.find_by(key: key)&.value
    end

    def system_config_value(key)
      SystemConfig.find_by(key: key)&.value
    end
  end
end
