class RolePermission < ApplicationRecord
  belongs_to :company

  validates :company_id, presence: true
  validates :role, presence: true
  validates :permission_key, presence: true
  validates :enabled, inclusion: { in: [ true, false ] }
  validates :permission_key, uniqueness: { scope: [ :company_id, :role ] }
end
