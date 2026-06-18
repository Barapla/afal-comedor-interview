require "test_helper"

class Admin::DishesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email_address: "admin-dishes@test.com",
      name: "Admin Test",
      role: "admin",
      password: "password"
    )
    sign_in_as(@admin)
    @dish = Dish.create!(name: "Platillo Admin", price_cents: 3_000, active: true)
  end

  test "destroy elimina platillo sin menu_items asociados" do
    assert_difference "Dish.count", -1 do
      delete admin_dish_path(@dish)
    end
    assert_redirected_to admin_dishes_path
    assert_equal "Platillo eliminado.", flash[:notice]
  end

  test "destroy muestra alerta cuando el platillo tiene menu_items asociados" do
    menu = DailyMenu.create!(menu_date: Date.current + 90)
    MenuItem.create!(daily_menu: menu, dish: @dish, stock: 5)

    assert_no_difference "Dish.count" do
      delete admin_dish_path(@dish)
    end
    assert_redirected_to admin_dishes_path
    assert flash[:alert].present?, "debe mostrar alerta de error"
  end
end
