require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "oi-test@example.com", name: "OI Test", role: "employee", password: "password")
    @menu = DailyMenu.create!(menu_date: Date.current + 60)
    @dish = Dish.create!(name: "Platillo", price_cents: 5_000, active: true)
    @menu_item = MenuItem.create!(daily_menu: @menu, dish: @dish, stock: 10)
    @order = @menu.orders.create!(user: @user, order_items_attributes: [])
  end

  test "no permite menu_item duplicado en la misma orden a nivel de modelo" do
    @order.order_items.create!(menu_item: @menu_item, price_cents: 5_000)
    duplicate = @order.order_items.build(menu_item: @menu_item, price_cents: 5_000)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:menu_item_id], "ya está en uso"
  end

  test "constraint único de BD rechaza duplicado incluso si la validación Rails falla" do
    @order.order_items.create!(menu_item: @menu_item, price_cents: 5_000)
    assert_raises(ActiveRecord::RecordNotUnique) do
      OrderItem.connection.execute(
        "INSERT INTO order_items (order_id, menu_item_id, price_cents, created_at, updated_at) " \
        "VALUES (#{@order.id}, #{@menu_item.id}, 5000, NOW(), NOW())"
      )
    end
  end
end
