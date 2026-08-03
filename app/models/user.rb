class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  alias_attribute :two_factor, :two_factor_enabled

  has_one_attached :avatar

  belongs_to :company, optional: true
  has_one :employee, dependent: :nullify
  has_many :created_import_templates, class_name: "ImportTemplate", foreign_key: :created_by, inverse_of: :creator, dependent: :nullify
  has_many :user_configs, dependent: :destroy
  has_many :role_permissions, through: :company

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :two_factor_method, presence: true, if: :two_factor_enabled?
  validate :two_factor_requires_pro_plan

  enum :role, {
    admin: 0,
    hr: 1,
    accountant: 2
  }
  enum :status, { active: 0, blocked: 1, invited: 2 }, prefix: true
  enum :onboarding_status, { unverified: 0, verified: 1 }, prefix: true
  enum :two_factor_method, { whatsapp_otp: "whatsapp_otp", authenticator: "authenticator" }, prefix: true

  scope :available_for_login, -> { status_active }

  def block!(reason: nil)
    update!(status: :blocked, blocked_at: Time.current, blocked_reason: reason)
  end

  def unblock!
    update!(status: :active, blocked_at: nil, blocked_reason: nil)
  end

  def active_for_authentication?
    super && status_active?
  end

  def inactive_message
    return :blocked unless status_active?

    super
  end

  def send_verification!
    update!(verification_token: SecureRandom.hex(16), verification_sent_at: Time.current)
  end

  def preference(key, fallback: nil)
    user_configs.find_by(key: key)&.value || fallback
  end

  def full_name
    [ first_name, last_name ].compact.join(" ").strip
  end

  def can_access_super_admin?
    super_admin?
  end

  def can?(permission_key)
    return true if super_admin?
    return false if company_id.blank? || role.blank? || permission_key.blank?

    RolePermission.exists?(
      company_id: company_id,
      role: role,
      permission_key: permission_key.to_s,
      enabled: true
    )
  end

  private

  def two_factor_requires_pro_plan
    return unless two_factor_enabled?
    return if company&.pro?

    errors.add(:two_factor_enabled, "is available on the pro plan only")
  end
end
