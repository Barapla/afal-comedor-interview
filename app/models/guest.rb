# frozen_string_literal: true

# Representa un comensal externo asociado a un pedido de empleado.
class Guest < ApplicationRecord
  belongs_to :order

  validates :name, presence: { message: 'El nombre del invitado es requerido' }
  validates :note, length: { maximum: 500 }, allow_blank: true
end
