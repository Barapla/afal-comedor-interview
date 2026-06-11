class CreateMenuItems < ActiveRecord::Migration[8.1]
  def change
    create_table :menu_items do |t|
      t.references :daily_menu, null: false, foreign_key: true
      t.references :dish, null: false, foreign_key: true
      t.integer :stock, null: false, default: 0

      t.timestamps
    end
    add_index :menu_items, [ :daily_menu_id, :dish_id ], unique: true
  end
end
