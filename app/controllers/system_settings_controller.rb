class SystemSettingsController < SystemConfigsController
	private

	def ensure_admin!
		return if current_user&.super_admin?

		redirect_to new_user_session_path, alert: "Access denied."
	end
end
