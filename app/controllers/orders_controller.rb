# frozen_string_literal: true

# Gestiona la creación, listado y visualización de pedidos de empleados.
class OrdersController < ApplicationController
  before_action :set_daily_menu, only: %i[new create]
  before_action :check_no_duplicate_order, only: [:create]

  OrderError = Class.new(StandardError)
  InsufficientStockError = Class.new(OrderError)

  def index
    @orders = Current.user.orders.includes(:daily_menu, order_items: { menu_item: :dish }).order(created_at: :desc)
  end

  def new
    @menu_items = @daily_menu.menu_items.joins(:dish).includes(:dish)
  end

  def create
    menu_item_ids, guests_attrs = validated_order_params
    build_and_save_order!(menu_item_ids, guests_attrs)
    redirect_to @order, notice: 'Pedido confirmado'
  rescue OrderError => e
    error_redirect(e.message)
  rescue ActiveRecord::RecordInvalid => e
    error_redirect("Error al crear el pedido: #{e.message}")
  rescue ActiveRecord::RecordNotUnique
    error_redirect('Ya tienes un pedido para el menú de hoy')
  end

  def show
    @order = Current.user.orders.includes(:guests, order_items: { menu_item: :dish }).find(params[:id])
  end

  private

  def validated_order_params
    menu_item_ids = Array(params[:menu_item_ids]).reject(&:blank?)
    raise OrderError, 'Debes seleccionar al menos un platillo' if menu_item_ids.empty?

    guests_attrs = parse_guest_params
    raise OrderError, 'El nombre del invitado es requerido' if guests_attrs.any? { |g| g[:name].blank? }

    [menu_item_ids, guests_attrs]
  end

  def build_and_save_order!(menu_item_ids, guests_attrs = [])
    ActiveRecord::Base.transaction do
      menu_items = fetch_and_validate_menu_items!(menu_item_ids)
      total_comensales = 1 + guests_attrs.size
      validate_stock!(menu_items, total_comensales)
      menu_items.each { |mi| mi.decrement!(:stock, total_comensales) }
      create_order_with_items!(menu_items, guests_attrs)
    end
  end

  def fetch_and_validate_menu_items!(menu_item_ids)
    menu_items = @daily_menu.menu_items.where(id: menu_item_ids).lock.includes(:dish).to_a
    raise InsufficientStockError, 'Ninguno de los platillos seleccionados está disponible' if menu_items.empty?

    if menu_items.size != menu_item_ids.uniq.size
      raise InsufficientStockError, 'Algunos platillos seleccionados no pertenecen al menú de hoy o están duplicados'
    end

    menu_items
  end

  def create_order_with_items!(menu_items, guests_attrs = [])
    @order = @daily_menu.orders.create!(user: Current.user)
    menu_items.each do |menu_item|
      @order.order_items.create!(menu_item: menu_item, price_cents: menu_item.price_cents)
    end
    guests_attrs.each do |guest_attr|
      @order.guests.create!(name: guest_attr[:name], note: guest_attr[:note])
    end
  end

  def validate_stock!(menu_items, total_comensales = 1)
    without_dish = menu_items.select { |mi| mi.dish.nil? }
    raise InsufficientStockError, 'Algunos platillos ya no están disponibles' if without_dish.any?

    insufficient = menu_items.select { |mi| mi.stock < total_comensales }
    return unless insufficient.any?

    names = insufficient.map { |mi| menu_item_display_name(mi) }.join(', ')
    raise InsufficientStockError, "Los siguientes platillos no tienen stock disponible: #{names}"
  end

  def parse_guest_params
    return [] unless params[:guests].present?

    params[:guests].map { |g| g.permit(:name, :note) }.reject { |g| g[:name].blank? && g[:note].blank? }
  end

  def menu_item_display_name(menu_item)
    menu_item.dish&.name || "platillo ##{menu_item.id}"
  end

  def check_no_duplicate_order
    error_redirect('Ya tienes un pedido para el menú de hoy') if @daily_menu.orders.exists?(user: Current.user)
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
