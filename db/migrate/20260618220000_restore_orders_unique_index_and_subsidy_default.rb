# frozen_string_literal: true

# Restaura el índice único [user_id, daily_menu_id] y el valor por defecto
# de subsidy_cents que fueron eliminados por migraciones intermedias sin archivo.
# Si existen pedidos duplicados antes de correr esta migración, ejecutar primero:
#   rails orders:remove_duplicates
class RestoreOrdersUniqueIndexAndSubsidyDefault < ActiveRecord::Migration[8.1]
  def up
    unless index_exists?(:orders, %i[user_id daily_menu_id], unique: true)
      add_index :orders, %i[user_id daily_menu_id], unique: true
    end
    change_column_default :orders, :subsidy_cents, from: nil, to: 10_000
  end

  def down
    remove_index :orders, %i[user_id daily_menu_id] if index_exists?(:orders, %i[user_id daily_menu_id])
    change_column_default :orders, :subsidy_cents, from: 10_000, to: nil
  end
end
