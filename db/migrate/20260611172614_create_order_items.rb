class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :menu_item, null: false, foreign_key: true
      t.integer :price_cents, null: false

      t.timestamps
    end
    # BUG: Falta restricción de unicidad a nivel de BD para (order_id, menu_item_id).
    # Sin este índice, un usuario puede agregar el mismo platillo dos veces en un pedido,
    # causando doble decremento de stock y doble cobro en el reporte de nómina.
    # POSIBLE FIX: add_index :order_items, [:order_id, :menu_item_id], unique: true
  end
end
