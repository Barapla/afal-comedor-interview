# frozen_string_literal: true

# Gestiona la creación, listado y visualización de pedidos de empleados.
# rubocop:disable Metrics/ClassLength -- coordina validación de stock, invitados y atomicidad transaccional
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
    menu_item_ids, guests_data = validated_order_params
    build_and_save_order!(menu_item_ids, guests_data)
    redirect_to @order, notice: 'Pedido confirmado'
  rescue OrderError => e
    error_redirect(e.message)
  rescue ActiveRecord::RecordInvalid => e
    error_redirect("Error al crear el pedido: #{e.message}")
  rescue ActiveRecord::RecordNotUnique
    error_redirect('Ya tienes un pedido para el menú de hoy')
  end

  def show
    @order = Current.user.orders
                    .includes(:daily_menu, order_items: { menu_item: :dish },
                                           guests: { guest_order_items: { menu_item: :dish } })
                    .find(params[:id])
  end

  private

  def validated_order_params
    menu_item_ids = Array(params[:menu_item_ids]).reject(&:blank?)
    raise OrderError, 'Debes seleccionar al menos un platillo' if menu_item_ids.empty?

    [menu_item_ids, parse_guest_params]
  end

  # rubocop:disable Metrics/AbcSize
  def build_and_save_order!(menu_item_ids, guests_data = [])
    ActiveRecord::Base.transaction do
      all_ids = (menu_item_ids + guests_data.flat_map { |g| g[:menu_item_ids] }).map(&:to_i).uniq
      items_map = @daily_menu.menu_items.where(id: all_ids).lock.includes(:dish).index_by(&:id)

      validate_items_present!(menu_item_ids.map(&:to_i), items_map)
      guests_data.each { |g| validate_items_present!(g[:menu_item_ids].map(&:to_i), items_map) }

      demands = build_demands(menu_item_ids, guests_data)
      validate_stock_demands!(demands, items_map)
      demands.each { |id, count| items_map[id].decrement!(:stock, count) }
      create_order_with_items!(menu_item_ids, guests_data, items_map)
    end
  end
  # rubocop:enable Metrics/AbcSize

  def parse_guest_params
    return [] unless params[:guests].present?

    raw = params[:guests]
    guests_list = raw.respond_to?(:keys) ? raw.values : Array(raw)
    guests_list.filter_map { |entry| parse_single_guest(entry) }
  end

  # rubocop:disable Metrics/AbcSize
  def parse_single_guest(entry)
    permitted = entry.permit(:name, :note, menu_item_ids: [])
    name = permitted[:name].to_s.strip
    note = permitted[:note].to_s
    ids = Array(permitted[:menu_item_ids]).reject(&:blank?)
    return if name.blank? && note.blank? && ids.empty?

    raise OrderError, 'El nombre del invitado es requerido' if name.blank?
    raise OrderError, 'Debes seleccionar al menos un platillo para el invitado' if ids.empty?

    { name: name, note: note, menu_item_ids: ids }
  end
  # rubocop:enable Metrics/AbcSize

  def build_demands(menu_item_ids, guests_data)
    demands = Hash.new(0)
    menu_item_ids.each { |id| demands[id.to_i] += 1 }
    guests_data.each { |g| g[:menu_item_ids].each { |id| demands[id.to_i] += 1 } }
    demands
  end

  def validate_items_present!(ids, items_map)
    return unless (ids - items_map.keys).any?

    raise InsufficientStockError, 'Algunos platillos seleccionados no pertenecen al menú de hoy o están duplicados'
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def validate_stock_demands!(demands, items_map)
    if demands.keys.any? { |id| items_map[id]&.dish.nil? }
      raise InsufficientStockError, 'Algunos platillos ya no están disponibles'
    end

    insufficient = demands.select { |id, count| items_map[id].stock < count }
    return unless insufficient.any?

    names = insufficient.keys.map { |id| items_map[id].dish&.name || "platillo ##{id}" }.join(', ')
    raise InsufficientStockError, "Los siguientes platillos no tienen stock disponible: #{names}"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize
  def create_order_with_items!(menu_item_ids, guests_data, items_map)
    @order = @daily_menu.orders.create!(user: Current.user)
    menu_item_ids.uniq(&:to_i).each do |id|
      @order.order_items.create!(menu_item: items_map[id.to_i], price_cents: items_map[id.to_i].price_cents)
    end
    guests_data.each do |gd|
      guest = @order.guests.create!(name: gd[:name], note: gd[:note])
      gd[:menu_item_ids].uniq(&:to_i).each do |id|
        guest.guest_order_items.create!(menu_item: items_map[id.to_i], price_cents: items_map[id.to_i].price_cents)
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

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
# rubocop:enable Metrics/ClassLength
