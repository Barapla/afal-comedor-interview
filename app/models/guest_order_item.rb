# frozen_string_literal: true

# Representa un platillo seleccionado por un invitado externo en un pedido.
class GuestOrderItem < ApplicationRecord
  belongs_to :guest
  belongs_to :menu_item

  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
