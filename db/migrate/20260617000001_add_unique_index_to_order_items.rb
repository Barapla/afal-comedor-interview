class AddUniqueIndexToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_index :order_items, [ :order_id, :menu_item_id ], unique: true
  end
end
