class OrdersController < ApplicationController
  before_action :set_daily_menu, only: [ :new, :create ]

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

    # BUG: El decremento de stock ocurre ANTES de que @order.save tenga éxito.
    # Si @order.save falla (ej: validación de unicidad), el stock ya fue decrementado
    # pero no se crea ninguna orden. El stock queda en estado incorrecto de forma silenciosa.
    # POSIBLE FIX: Mover toda esta lógica dentro de una transacción y ejecutar el decremento
    # sólo si @order.save es exitoso, o usar un servicio transaccional.
    #
    # BUG: No hay validación de stock disponible antes de decrementar.
    # Si stock == 0, menu_item.update resulta en stock = -1 sin ningún error.
    # POSIBLE FIX: Verificar menu_item.stock > 0 antes de decrementar y abortar si no hay stock.
    #
    # BUG: Race condition — menu_item.stock - 1 lee el stock y luego lo escribe en dos pasos
    # separados. Dos requests concurrentes pueden leer stock=1, ambas decrementan a 0 y salvan,
    # resultando en stock=-1 o dos órdenes para el mismo platillo sin stock.
    # POSIBLE FIX: Usar UPDATE atómico: menu_item.with_lock { menu_item.decrement!(:stock) }
    # o menu_item.update_counters(stock: -1) con una condición WHERE stock > 0.
    #
    # BUG: N+1 query — MenuItem.find(item.menu_item_id) se ejecuta una vez por cada order_item
    # dentro del loop. Para N platillos, genera N queries adicionales.
    # POSIBLE FIX: Pre-cargar los menu_items antes del loop con un Map<id, record>.
    #
    # BUG: No hay transacción englobando los decrementos de stock + @order.save.
    # Si el segundo decremento falla, el primero ya fue persistido pero la orden no existe.
    # POSIBLE FIX: Envolver todo en ActiveRecord::Base.transaction do ... end
    @order.order_items.each do |item|
      menu_item = MenuItem.find(item.menu_item_id)
      menu_item.update(stock: menu_item.stock - 1)
      item.price_cents = menu_item.price_cents
    end

    if @order.save
      redirect_to @order, notice: "Pedido confirmado"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @order = Current.user.orders.includes(order_items: { menu_item: :dish }).find(params[:id])
  end

  private
    def set_daily_menu
      @daily_menu = DailyMenu.today
      redirect_to root_path, alert: "No hay menú disponible hoy." if @daily_menu.nil?
    end

    def order_params
      params.expect(order: [ order_items_attributes: [ [ :menu_item_id, :_destroy ] ] ])
    end
end
