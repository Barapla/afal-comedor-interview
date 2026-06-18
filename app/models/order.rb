class Order < ApplicationRecord
  STATUSES = %w[pending confirmed cancelled].freeze
  DEFAULT_SUBSIDY_CENTS = 10_000

  belongs_to :user
  belongs_to :daily_menu
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

  validates :status, inclusion: { in: STATUSES }
  # BUG: La validación de unicidad a nivel de modelo no protege contra race conditions.
  # Dos requests concurrentes pueden pasar la validación antes de que ninguna haya persistido.
  # POSIBLE FIX: La restricción unique index en BD (user_id, daily_menu_id) en la migración
  # atrapa el duplicado a nivel DB, pero el controlador debe rescatar ActiveRecord::RecordNotUnique
  # y devolver un error amigable al usuario en lugar de un 500.
  validates :user_id, uniqueness: { scope: :daily_menu_id }

  # DEUDA TÉCNICA: No hay validación de que subsidy_cents >= 0. Un valor negativo
  # haría que subsidy_applied_cents devuelva un número negativo si items_total_cents < 0.
  # POSIBLE FIX: validates :subsidy_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :assign_defaults, on: :create

  # DEUDA TÉCNICA: items_total_cents dispara una consulta SQL cada vez que se llama.
  # Si se invoca múltiples veces en el mismo request (ej: subsidy_applied_cents y amount_due_cents
  # en el mismo render) ejecuta 3 queries en vez de 1.
  # POSIBLE FIX: Memoizar con @items_total_cents ||= order_items.sum(:price_cents)
  # o usar order_items.loaded? para calcular desde memoria si ya fueron cargados.
  def items_total_cents
    order_items.sum(:price_cents)
  end

  def subsidy_applied_cents
    [ items_total_cents, subsidy_cents ].min
  end

  def amount_due_cents
    items_total_cents - subsidy_applied_cents
  end

  private
    def assign_defaults
      self.status ||= "pending"
      self.subsidy_cents ||= DEFAULT_SUBSIDY_CENTS
    end
end
