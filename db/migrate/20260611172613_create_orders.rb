class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :daily_menu, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :subsidy_cents, null: false, default: 10_000

      t.timestamps
    end
    add_index :orders, [ :user_id, :daily_menu_id ], unique: true
  end
end
