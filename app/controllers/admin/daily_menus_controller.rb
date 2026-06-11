class Admin::DailyMenusController < Admin::BaseController
  before_action :set_daily_menu, only: [ :show, :destroy ]

  def index
    @daily_menus = DailyMenu.order(menu_date: :desc).limit(30)
  end

  def show
    @menu_items = @daily_menu.menu_items.includes(:dish)
    @available_dishes = Dish.active.where.not(id: @daily_menu.dish_ids).order(:name)
  end

  def new
    @daily_menu = DailyMenu.new(menu_date: Date.current)
  end

  def create
    @daily_menu = DailyMenu.new(daily_menu_params)
    if @daily_menu.save
      redirect_to admin_daily_menu_path(@daily_menu), notice: "Menú del día creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @daily_menu.destroy
    redirect_to admin_daily_menus_path, notice: "Menú eliminado."
  rescue ActiveRecord::DeleteRestrictionError
    redirect_to admin_daily_menus_path, alert: "No se puede eliminar: ya tiene órdenes."
  end

  private
    def set_daily_menu
      @daily_menu = DailyMenu.find(params[:id])
    end

    def daily_menu_params
      params.expect(daily_menu: [ :menu_date ])
    end
end
