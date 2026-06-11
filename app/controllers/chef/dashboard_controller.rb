class Chef::DashboardController < ApplicationController
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
