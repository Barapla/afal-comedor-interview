class CreateDailyMenus < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_menus do |t|
      t.date :menu_date, null: false

      t.timestamps
    end
    add_index :daily_menus, :menu_date, unique: true
  end
end
