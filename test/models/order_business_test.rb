require "test_helper"

class OrderBusinessTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "biz@test.com",
      name: "Test User",
      role: "employee",
      password: "password"
    )
    @menu = DailyMenu.create!(menu_date: Date.current + 30)
    @dish_a = Dish.create!(name: "A", price_cents: 6_000, active: true)
    @dish_b = Dish.create!(name: "B", price_cents: 8_000, active: true)
    @item_a = MenuItem.create!(daily_menu: @menu, dish: @dish_a, stock: 10)
    @item_b = MenuItem.create!(daily_menu: @menu, dish: @dish_b, stock: 10)
  end

  test "amount_due is zero when items total is under subsidy" do
    order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [ { menu_item_id: @item_a.id, price_cents: @dish_a.price_cents } ]
    )

    assert_equal 6_000, order.items_total_cents
    assert_equal 6_000, order.subsidy_applied_cents
    assert_equal 0, order.amount_due_cents
  end

  test "amount_due is items_total minus subsidy when items exceed subsidy" do
    order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [
        { menu_item_id: @item_a.id, price_cents: @dish_a.price_cents },
        { menu_item_id: @item_b.id, price_cents: @dish_b.price_cents }
      ]
    )

    assert_equal 14_000, order.items_total_cents
    assert_equal 10_000, order.subsidy_applied_cents
    assert_equal 4_000, order.amount_due_cents
  end

  test "one order per user per daily menu" do
    @menu.orders.create!(
      user: @user,
      order_items_attributes: [ { menu_item_id: @item_a.id, price_cents: @dish_a.price_cents } ]
    )
    duplicate = @menu.orders.new(
      user: @user,
      order_items_attributes: [ { menu_item_id: @item_b.id, price_cents: @dish_b.price_cents } ]
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "ya está en uso"
  end

end
