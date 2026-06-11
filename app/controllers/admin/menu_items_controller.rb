class Admin::MenuItemsController < Admin::BaseController
  before_action :set_daily_menu
  before_action :set_menu_item, only: [ :update, :destroy ]

  def create
    @menu_item = @daily_menu.menu_items.new(menu_item_params)
    if @menu_item.save
      redirect_to admin_daily_menu_path(@daily_menu), notice: "Platillo agregado al menú."
    else
      redirect_to admin_daily_menu_path(@daily_menu), alert: @menu_item.errors.full_messages.to_sentence
    end
  end

  def update
    if @menu_item.update(menu_item_params)
      redirect_to admin_daily_menu_path(@daily_menu), notice: "Stock actualizado."
    else
      redirect_to admin_daily_menu_path(@daily_menu), alert: @menu_item.errors.full_messages.to_sentence
    end
  end

  def destroy
    @menu_item.destroy
    redirect_to admin_daily_menu_path(@daily_menu), notice: "Platillo removido del menú."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to admin_daily_menu_path(@daily_menu), alert: "No se puede eliminar: ya tiene órdenes."
  end

  private
    def set_daily_menu
      @daily_menu = DailyMenu.find(params[:daily_menu_id])
    end

    def set_menu_item
      @menu_item = @daily_menu.menu_items.find(params[:id])
    end

    def menu_item_params
      params.expect(menu_item: [ :dish_id, :stock ])
    end
end
