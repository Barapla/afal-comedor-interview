# frozen_string_literal: true

# Crea la tabla de invitados externos asociados a pedidos de empleados.
class CreateGuests < ActiveRecord::Migration[8.1]
  def up
    # Limpieza de intento anterior con diseño diferente
    drop_table :order_guests, if_exists: true
    drop_table :guests, if_exists: true

    create_table :guests do |t|
      t.references :order, null: false, foreign_key: true
      t.string :name, null: false
      t.text :note

      t.timestamps
    end

    add_index :guests, %i[order_id created_at]
  end

  def down
    drop_table :guests
  end
end
