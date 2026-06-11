class CreateDishes < ActiveRecord::Migration[8.1]
  def change
    create_table :dishes do |t|
      t.string :name, null: false
      t.text :description
      t.integer :price_cents, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
