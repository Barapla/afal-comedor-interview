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
