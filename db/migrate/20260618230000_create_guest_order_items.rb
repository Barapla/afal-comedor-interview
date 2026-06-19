# frozen_string_literal: true

# Crea la tabla de platillos seleccionados por cada invitado externo.
# Permite que cada invitado elija sus propios platillos independientemente del empleado.
class CreateGuestOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :guest_order_items do |t|
      t.references :guest, null: false, foreign_key: true
      t.references :menu_item, null: false, foreign_key: true
      t.integer :price_cents, null: false

      t.timestamps
    end

    add_index :guest_order_items, %i[guest_id menu_item_id], unique: true
  end
end
