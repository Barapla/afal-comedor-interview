# frozen_string_literal: true

# Representa un comensal externo asociado a un pedido de empleado.
class Guest < ApplicationRecord
  belongs_to :order
  has_many :guest_order_items, dependent: :destroy
  has_many :menu_items, through: :guest_order_items

  validates :name, presence: { message: 'El nombre del invitado es requerido' }
  validates :note, length: { maximum: 500 }, allow_blank: true
end
