# frozen_string_literal: true

namespace :orders do
  desc 'Elimina pedidos duplicados conservando el más antiguo. Ejecutar antes de restaurar el índice único en orders.'
  task remove_duplicates: :environment do
    dup_ids = Order.where.not(
      id: Order.select('MIN(id)').group(:user_id, :daily_menu_id)
    ).pluck(:id)

    if dup_ids.empty?
      puts 'Sin pedidos duplicados. Nada que limpiar.'
      next
    end

    puts "Se encontraron #{dup_ids.size} pedido(s) duplicado(s): #{dup_ids.inspect}"

    ActiveRecord::Base.transaction do
      OrderItem.where(order_id: dup_ids).delete_all
      Guest.where(order_id: dup_ids).delete_all
      Order.where(id: dup_ids).delete_all
    end

    puts 'Limpieza completada.'
  end
end
