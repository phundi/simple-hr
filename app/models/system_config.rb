class SystemConfig < ApplicationRecord
  enum :data_type, {
    string: "string",
    number: "number",
    boolean: "boolean",
    text: "text"
  }, prefix: true

  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validates :data_type, inclusion: { in: data_types.keys }, allow_blank: true
end
