# frozen_string_literal: true

class AddGuestToOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :orders, :guest, null: true, foreign_key: true

    # El índice único original no soporta múltiples órdenes por empleado (propias + invitados).
    # Se reemplaza por dos índices parciales:
    #   1. Un empleado solo puede tener una orden propia por menú (guest_id IS NULL).
    #   2. Un empleado solo puede tener una orden por invitado por menú.
    remove_index :orders, name: "index_orders_on_user_id_and_daily_menu_id"
    add_index :orders, [ :user_id, :daily_menu_id ], unique: true,
              where: "guest_id IS NULL", name: "index_orders_own_per_menu"
    add_index :orders, [ :user_id, :daily_menu_id, :guest_id ], unique: true,
              name: "index_orders_guest_per_menu"
  end
end
