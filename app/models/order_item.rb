class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :menu_item

  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :menu_item_id, uniqueness: { scope: :order_id }
end
