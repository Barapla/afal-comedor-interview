# frozen_string_literal: true

# Representa un pedido diario de comedor de un empleado, incluyendo invitados opcionales.
class Order < ApplicationRecord
  STATUSES = %w[pending confirmed cancelled].freeze
  DEFAULT_SUBSIDY_CENTS = 10_000

  belongs_to :user
  belongs_to :daily_menu
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items
  has_many :guests, dependent: :destroy

  accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :daily_menu_id }
  validates :subsidy_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :assign_defaults, on: :create

  def items_total_cents
    @items_total_cents ||= order_items.loaded? ? order_items.sum(&:price_cents) : order_items.sum(:price_cents)
  end

  def subsidy_applied_cents
    [items_total_cents, subsidy_cents].min
  end

  def amount_due_cents
    items_total_cents - subsidy_applied_cents
  end

  def guests_total_cents
    guest_count = guests.loaded? ? guests.size : guests.count
    guest_count * items_total_cents
  end

  def total_payroll_deduction_cents
    amount_due_cents + guests_total_cents
  end

  private

  def assign_defaults
    self.status ||= 'pending'
    self.subsidy_cents ||= DEFAULT_SUBSIDY_CENTS
  end
end
