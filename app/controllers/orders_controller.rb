# frozen_string_literal: true

# Gestiona la creación, listado y visualización de pedidos del empleado y sus invitados.
class OrdersController < ApplicationController
  before_action :set_daily_menu, only: %i[new create]

  InsufficientStockError = Class.new(StandardError)
  DuplicateOrderError    = Class.new(StandardError)

  def index
    @orders = Current.user.orders
                          .includes(:order_guest, :guest, :daily_menu, order_items: { menu_item: :dish })
                          .order(created_at: :desc)
  end

  def new
    @menu_items = @daily_menu.menu_items.joins(:dish).includes(:dish)
    @guests     = Current.user.guests.order(:name)
  end

  def create
    menu_item_ids    = Array(params[:menu_item_ids]).reject(&:blank?)
    guest_items_raw  = extract_guest_order_params

    if menu_item_ids.empty? && guest_items_raw.values.all?(&:empty?)
      return error_redirect("Debes seleccionar al menos un platillo para ti o para un invitado")
    end

    build_and_save_all_orders!(menu_item_ids, guest_items_raw)
    redirect_to orders_path, notice: "Pedido confirmado"
  rescue InsufficientStockError => e
    error_redirect(e.message)
  rescue DuplicateOrderError => e
    error_redirect(e.message)
  rescue ActiveRecord::RecordInvalid => e
    error_redirect("Error al crear el pedido: #{e.message}")
  rescue ActiveRecord::RecordNotUnique
    error_redirect("Ya existe un pedido para el menú de hoy")
  end

  def show
    @order = Current.user.orders
                         .includes(:order_guest, :guest, order_items: { menu_item: :dish })
                         .find(params[:id])
  end

  private

  def build_and_save_all_orders!(menu_item_ids, guest_items_raw)
    ActiveRecord::Base.transaction do
      all_ids = (menu_item_ids + guest_items_raw.values.flatten).map(&:to_i).uniq
      menu_items_index = @daily_menu.menu_items.where(id: all_ids).lock.includes(:dish).index_by(&:id)

      if menu_item_ids.any?
        check_no_own_order_duplicate!
        items = fetch_items!(menu_item_ids, menu_items_index)
        validate_stock!(items)
        items.each { |mi| mi.decrement!(:stock) }
        create_order_with_items!(items, guest: nil)
      end

      guest_items_raw.each do |guest_id, item_ids|
        next if item_ids.empty?

        guest = Current.user.guests.find_by(id: guest_id.to_i)
        next unless guest

        items = fetch_items!(item_ids, menu_items_index)
        validate_stock!(items)
        items.each { |mi| mi.decrement!(:stock) }
        create_order_with_items!(items, guest: guest)
      end
    end
  end

  def create_order_with_items!(menu_items, guest:)
    subsidy = guest ? 0 : nil
    order = @daily_menu.orders.create!(user: Current.user, subsidy_cents: subsidy)
    OrderGuest.create!(order: order, guest: guest) if guest
    menu_items.each do |menu_item|
      order.order_items.create!(menu_item: menu_item, price_cents: menu_item.price_cents)
    end
  end

  def fetch_items!(item_ids, menu_items_index)
    items = item_ids.map { |id| menu_items_index[id.to_i] }.compact
    raise InsufficientStockError, "Ninguno de los platillos seleccionados está disponible" if items.empty?

    if items.size != item_ids.map(&:to_i).uniq.size
      raise InsufficientStockError, "Algunos platillos seleccionados no pertenecen al menú de hoy"
    end

    items
  end

  def validate_stock!(menu_items)
    out_of_stock = menu_items.select { |mi| mi.stock <= 0 }
    return unless out_of_stock.any?

    names = out_of_stock.map { |mi| mi.dish&.name || "platillo ##{mi.id}" }.join(", ")
    raise InsufficientStockError, "Los siguientes platillos no tienen stock disponible: #{names}"
  end

  def check_no_own_order_duplicate!
    own_order_exists = @daily_menu.orders
                                  .where(user: Current.user)
                                  .where.not(id: OrderGuest.select(:order_id))
                                  .exists?
    raise DuplicateOrderError, "Ya tienes un pedido para el menú de hoy" if own_order_exists
  end

  def error_redirect(message)
    flash[:error] = message
    redirect_to new_order_path
  end

  def set_daily_menu
    @daily_menu = DailyMenu.today
    redirect_to root_path, alert: "No hay menú disponible hoy." if @daily_menu.nil?
  end

  def extract_guest_order_params
    raw = params[:guest_orders]
    return {} unless raw.is_a?(ActionController::Parameters)

    raw.permit!.to_h.transform_values { |ids| Array(ids).map(&:to_s).reject(&:blank?) }
  end
end
