class Admin::DishesController < Admin::BaseController
  before_action :set_dish, only: [ :edit, :update, :destroy ]

  def index
    @dishes = Dish.order(:name)
  end

  def new
    @dish = Dish.new
  end

  def create
    @dish = Dish.new(dish_params)
    if @dish.save
      redirect_to admin_dishes_path, notice: "Platillo creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @dish.update(dish_params)
      redirect_to admin_dishes_path, notice: "Platillo actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @dish.destroy!
    redirect_to admin_dishes_path, notice: "Platillo eliminado."
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to admin_dishes_path, alert: "No se puede eliminar: el platillo tiene ítems de menú asociados."
  end

  private
    def set_dish
      @dish = Dish.find(params[:id])
    end

    def dish_params
      params.expect(dish: [ :name, :description, :price_cents, :active ])
    end
end
