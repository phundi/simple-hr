class ImportTemplate < ApplicationRecord
  belongs_to :company
  belongs_to :creator, class_name: "User", foreign_key: :created_by, optional: true, inverse_of: :created_import_templates
  has_many :employees, dependent: :nullify

  has_one_attached :file

  enum :status, { draft: 0, active: 1 }, default: :draft
end
