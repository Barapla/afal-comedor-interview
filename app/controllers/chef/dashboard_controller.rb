class Chef::DashboardController < ApplicationController
  # DEUDA TÉCNICA: Este controlador hereda de ApplicationController en lugar de un
  # Chef::BaseController inexistente. Si se agregan más controladores bajo Chef::,
  # cada uno deberá recordar agregar before_action :require_chef manualmente.
  # POSIBLE FIX: Crear app/controllers/chef/base_controller.rb con require_chef centralizado,
  # similar a Admin::BaseController, y heredar de él.
  before_action :require_chef

  def show
    @daily_menu = DailyMenu.today
    @summary = if @daily_menu
      @daily_menu.menu_items.includes(:dish, :order_items).map do |item|
        {
          dish: item.dish,
          stock: item.stock,
          ordered: item.order_items.joins(:order).where(orders: { status: %w[pending confirmed] }).count
        }
      end
    else
      []
    end
  end

  private
    def require_chef
      redirect_to root_path, alert: "No autorizado." unless Current.user&.chef? || Current.user&.admin?
    end
end
