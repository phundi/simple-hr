Rails.application.config.to_prepare do
  begin
    next unless ActiveRecord::Base.connection.data_source_exists?("system_configs")

    smtp_address = SystemConfig.find_by(key: "smtp_address")&.value.presence || "smtp.sendgrid.net"
    smtp_port = (SystemConfig.find_by(key: "smtp_port")&.value.presence || "587").to_i

    ActionMailer::Base.smtp_settings = ActionMailer::Base.smtp_settings.to_h.merge(
      address: smtp_address,
      port: smtp_port
    )
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
    # Skip dynamic mailer settings when database is unavailable.
  end
end
