class MenuItem < ApplicationRecord
  belongs_to :daily_menu
  belongs_to :dish
  has_many :order_items, dependent: :restrict_with_error

  validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :dish_id, uniqueness: { scope: :daily_menu_id }

  delegate :name, :description, :price_cents, to: :dish
end
