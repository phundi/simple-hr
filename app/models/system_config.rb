class SystemConfig < ApplicationRecord
  validates :key, presence: true, uniqueness: { case_sensitive: false }
end
