# frozen_string_literal: true

# Restaura el índice único [user_id, daily_menu_id] y el valor por defecto
# de subsidy_cents que fueron eliminados por migraciones intermedias sin archivo.
# Elimina pedidos duplicados (con sus dependencias) creados mientras el índice estuvo ausente.
class RestoreOrdersUniqueIndexAndSubsidyDefault < ActiveRecord::Migration[8.1]
  def up
    remove_duplicate_orders
    unless index_exists?(:orders, %i[user_id daily_menu_id], unique: true)
      add_index :orders, %i[user_id daily_menu_id], unique: true
    end
    change_column_default :orders, :subsidy_cents, from: nil, to: 10_000
  end

  def down
    remove_index :orders, %i[user_id daily_menu_id] if index_exists?(:orders, %i[user_id daily_menu_id])
    change_column_default :orders, :subsidy_cents, from: 10_000, to: nil
  end

  private

  def remove_duplicate_orders
    dup_sql = 'SELECT id FROM orders WHERE id NOT IN (SELECT MIN(id) FROM orders GROUP BY user_id, daily_menu_id)'
    execute "DELETE FROM order_items WHERE order_id IN (#{dup_sql})"
    execute "DELETE FROM guests WHERE order_id IN (#{dup_sql})"
    execute "DELETE FROM orders WHERE id IN (#{dup_sql})"
  end
end
