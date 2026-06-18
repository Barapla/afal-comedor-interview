# frozen_string_literal: true

# Gestiona la creación, listado y visualización de pedidos de empleados.
class OrdersController < ApplicationController
  before_action :set_daily_menu, only: %i[new create]

  InsufficientStockError = Class.new(StandardError)

  def index
    @orders = Current.user.orders.includes(:daily_menu, order_items: { menu_item: :dish }).order(created_at: :desc)
  end

  def new
    @menu_items = @daily_menu.menu_items.includes(:dish)
  end

  def create
    menu_item_ids = Array(params[:menu_item_ids]).reject(&:blank?)
    return error_redirect('Debes seleccionar al menos un platillo') if menu_item_ids.empty?

    build_and_save_order!(menu_item_ids)
    redirect_to @order, notice: 'Pedido confirmado'
  rescue InsufficientStockError => e
    error_redirect(e.message)
  rescue ActiveRecord::RecordInvalid => e
    error_redirect("Error al crear el pedido: #{e.message}")
  rescue ActiveRecord::RecordNotUnique
    error_redirect('Ya tienes un pedido para el menú de hoy')
  end

  def show
    @order = Current.user.orders.includes(order_items: { menu_item: :dish }).find(params[:id])
  end

  private

  def build_and_save_order!(menu_item_ids)
    ActiveRecord::Base.transaction do
      menu_items = MenuItem.includes(:dish).lock.where(id: menu_item_ids)
      validate_stock!(menu_items)
      @order = @daily_menu.orders.create!(user: Current.user)
      menu_items.each do |menu_item|
        @order.order_items.create!(menu_item: menu_item, price_cents: menu_item.price_cents)
        menu_item.decrement!(:stock)
      end
    end
  end

  def validate_stock!(menu_items)
    out_of_stock = menu_items.select { |mi| mi.stock <= 0 }
    return unless out_of_stock.any?

    names = out_of_stock.map { |mi| mi.dish&.name || 'Platillo eliminado' }.join(', ')
    raise InsufficientStockError, "Los siguientes platillos no tienen stock disponible: #{names}"
  end

  def error_redirect(message)
    flash[:error] = message
    redirect_to new_order_path
  end

  def set_daily_menu
    @daily_menu = DailyMenu.today
    redirect_to root_path, alert: 'No hay menú disponible hoy.' if @daily_menu.nil?
  end
end
