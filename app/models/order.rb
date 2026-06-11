class Order < ApplicationRecord
  STATUSES = %w[pending confirmed cancelled].freeze
  DEFAULT_SUBSIDY_CENTS = 10_000

  belongs_to :user
  belongs_to :daily_menu
  has_many :order_items, dependent: :destroy
  has_many :menu_items, through: :order_items

  accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :daily_menu_id }

  before_validation :assign_defaults, on: :create

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
