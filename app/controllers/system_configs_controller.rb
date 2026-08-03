class SystemConfigsController < ApplicationController
  before_action :ensure_admin!
  before_action :set_system_config, only: :update

  def index
    @system_configs = SystemConfig.order(:category, :key)
    @grouped_configs = @system_configs.group_by { |cfg| cfg.category.presence || "General" }
  end

  def update
    if @system_config.update(system_config_params)
      redirect_to system_configs_path, notice: "System config updated."
    else
      @system_configs = SystemConfig.order(:category, :key)
      @grouped_configs = @system_configs.group_by { |cfg| cfg.category.presence || "General" }
      flash.now[:alert] = @system_config.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  private

  def ensure_admin!
    return if current_user&.admin? || current_user&.super_admin?

    redirect_to new_user_session_path, alert: "Access denied."
  end

  def set_system_config
    @system_config = SystemConfig.find(params[:id])
  end

  def system_config_params
    attrs = params.require(:system_config).permit(:value)
    attrs[:value] = normalize_value(@system_config.data_type, attrs[:value])
    attrs
  end

  def normalize_value(data_type, raw_value)
    case data_type
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(raw_value) ? "true" : "false"
    when "number"
      raw_value.to_s.strip
    else
      raw_value.to_s
    end
  end
end
