class User < ApplicationRecord
  ROLES = %w[employee admin chef].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :orders, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }
  # DEUDA TÉCNICA: No hay validación de presencia ni formato de email_address a nivel de modelo.
  # La restricción NOT NULL existe en BD pero un string vacío "" pasaría la validación.
  # POSIBLE FIX: validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  #
  # DEUDA TÉCNICA: No hay validación de unicidad de email_address en el modelo.
  # La restricción unique index en BD evita duplicados, pero si se viola, Rails lanza
  # ActiveRecord::RecordNotUnique en lugar de un error de validación amigable.
  # POSIBLE FIX: validates :email_address, uniqueness: { case_sensitive: false }

  def admin?    = role == "admin"
  def chef?     = role == "chef"
  def employee? = role == "employee"
end
