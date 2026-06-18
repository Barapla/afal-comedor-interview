class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :menu_item

  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  # BUG: No hay validación de unicidad de menu_item_id dentro de una misma order.
  # Un usuario podría agregar el mismo platillo dos veces en un pedido, decrementando
  # el stock dos veces y cobrando el platillo duplicado.
  # POSIBLE FIX: validates :menu_item_id, uniqueness: { scope: :order_id }
  # y add_index :order_items, [:order_id, :menu_item_id], unique: true en una migración.
end
