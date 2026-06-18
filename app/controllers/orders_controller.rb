# frozen_string_literal: true

# Gestiona la creación, listado y visualización de pedidos de empleados.
class OrdersController < ApplicationController
  before_action :set_daily_menu, only: %i[new create]

  InsufficientStockError = Class.new(StandardError)
  DataIntegrityError = Class.new(StandardError)

  def index
    @orders = Current.user.orders.includes(:daily_menu, order_items: { menu_item: :dish }).order(created_at: :desc)
  end

  def new
    @order = @daily_menu.orders.new(user: Current.user)
    @daily_menu.menu_items.includes(:dish).each { |mi| @order.order_items.build(menu_item: mi) }
  end

  def create
    @order = @daily_menu.orders.new(order_params)
    @order.user = Current.user
    process_order!
    redirect_to @order, notice: 'Pedido confirmado'
  rescue InsufficientStockError, DataIntegrityError, ActiveRecord::RecordInvalid => e
    @order.errors.add(:base, e.message)
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique
    @order.errors.add(:base, 'Ya tienes un pedido para el menú de hoy')
    render :new, status: :unprocessable_entity
  end

  def show
    @order = Current.user.orders.includes(order_items: { menu_item: :dish }).find(params[:id])
  end

  private

  def process_order!
    ActiveRecord::Base.transaction do
      menu_items = MenuItem.includes(:dish).lock.where(id: @order.order_items.map(&:menu_item_id)).index_by(&:id)
      @order.order_items.each { |item| process_item!(item, menu_items) }
      @order.save!
    end
  end

  def process_item!(item, menu_items)
    mi = menu_items[item.menu_item_id]
    raise DataIntegrityError, 'Artículo de menú no encontrado' unless mi
    raise DataIntegrityError, 'El platillo fue eliminado y no está disponible' unless mi.dish

    raise InsufficientStockError, "Sin stock disponible para #{mi.dish.name}" if mi.stock <= 0

    mi.decrement!(:stock)
    item.price_cents = mi.price_cents
  end

  def set_daily_menu
    @daily_menu = DailyMenu.today
    redirect_to root_path, alert: 'No hay menú disponible hoy.' if @daily_menu.nil?
  end

  def order_params
    params.expect(order: [{ order_items_attributes: [%i[menu_item_id _destroy]] }])
  end
end
