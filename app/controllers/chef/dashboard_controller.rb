class Chef::DashboardController < Chef::BaseController
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
end
