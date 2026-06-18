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

  test "subsidy_cents no puede ser negativo" do
    order = @menu.orders.new(user: @user, subsidy_cents: -1)
    order.status = "pending"
    assert_not order.valid?
    assert order.errors[:subsidy_cents].any?
  end

  test "items_total_cents usa items cargados en memoria sin disparar consulta extra" do
    order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [ { menu_item_id: @item_a.id, price_cents: 6_000 } ]
    )
    order_with_items = Order.includes(:order_items).find(order.id)

    assert order_with_items.order_items.loaded?
    assert_equal 6_000, order_with_items.items_total_cents
  end

  test "items_total_cents se memoiza al llamarse múltiples veces" do
    order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [ { menu_item_id: @item_a.id, price_cents: 6_000 } ]
    )
    total1 = order.items_total_cents
    total2 = order.items_total_cents
    assert_equal total1, total2
    assert_equal order.instance_variable_get(:@items_total_cents), 6_000
  end

  test "guest_order? es false para pedido propio" do
    order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [ { menu_item_id: @item_a.id, price_cents: @dish_a.price_cents } ]
    )
    order_loaded = Order.includes(:order_guest).find(order.id)
    assert_not order_loaded.guest_order?
  end

  test "guest_order? es true cuando hay order_guest asociado" do
    guest = @user.guests.create!(name: "Invitado Test")
    order = @menu.orders.create!(user: @user, subsidy_cents: 0)
    OrderGuest.create!(order: order, guest: guest)

    order_loaded = Order.includes(:order_guest).find(order.id)
    assert order_loaded.guest_order?
  end

  test "order_guest garantiza que el mismo invitado no tenga dos pedidos en el mismo menú" do
    guest = @user.guests.create!(name: "Invitado Test")
    order_a = @menu.orders.create!(user: @user, subsidy_cents: 0)
    OrderGuest.create!(order: order_a, guest: guest)

    order_b = @menu.orders.create!(user: @user, subsidy_cents: 0)
    duplicate = OrderGuest.new(order: order_b, guest: guest)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:guest_id], "ya está en uso"
  end

  test "empleado puede tener pedido propio y pedido de invitado en el mismo menú" do
    guest = @user.guests.create!(name: "Invitado Test")

    own_order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [ { menu_item_id: @item_a.id, price_cents: @dish_a.price_cents } ]
    )
    guest_order = @menu.orders.create!(user: @user, subsidy_cents: 0)
    OrderGuest.create!(order: guest_order, guest: guest)

    assert own_order.persisted?
    assert guest_order.persisted?
    assert_equal Order::DEFAULT_SUBSIDY_CENTS, own_order.subsidy_cents
    assert_equal 0, guest_order.subsidy_cents
  end
end
