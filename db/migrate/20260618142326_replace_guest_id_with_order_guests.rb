# frozen_string_literal: true

class ReplaceGuestIdWithOrderGuests < ActiveRecord::Migration[8.1]
  def up
    remove_index :orders, name: "index_orders_own_per_menu"
    remove_index :orders, name: "index_orders_guest_per_menu"
    remove_reference :orders, :guest, foreign_key: true, null: true

    create_table :order_guests do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :guest, null: false, foreign_key: true
      t.timestamps
    end
  end

  def down
    drop_table :order_guests

    add_reference :orders, :guest, null: true, foreign_key: true
    add_index :orders, [ :user_id, :daily_menu_id ], unique: true,
              where: "guest_id IS NULL", name: "index_orders_own_per_menu"
    add_index :orders, [ :user_id, :daily_menu_id, :guest_id ], unique: true,
              name: "index_orders_guest_per_menu"
  end
end
