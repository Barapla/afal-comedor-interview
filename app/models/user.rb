class User < ApplicationRecord
  ROLES = %w[employee admin chef].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :guests, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :email_address, presence: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP },
                            uniqueness: { case_sensitive: false }

  def admin?    = role == "admin"
  def chef?     = role == "chef"
  def employee? = role == "employee"
end
