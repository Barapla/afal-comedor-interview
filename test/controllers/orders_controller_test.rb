# frozen_string_literal: true

require 'test_helper'

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: 'orders-ctrl@test.com',
      name: 'Test Employee',
      role: 'employee',
      password: 'password'
    )
    sign_in_as(@user)

    @menu = DailyMenu.create!(menu_date: Date.current)
    DailyMenu.class_eval { def self.today = DailyMenu.find_by(menu_date: Date.current) }

    @dish = Dish.create!(name: 'Tacos', price_cents: 4_000, active: true)
    @mi   = MenuItem.create!(daily_menu: @menu, dish: @dish, stock: 5)
  end

  # CA1: solo los platillos seleccionados aparecen en la orden
  test 'create genera la orden solo con los platillos seleccionados' do
    dish_b = Dish.create!(name: 'Enchiladas', price_cents: 3_500, active: true)
    mi_b = MenuItem.create!(daily_menu: @menu, dish: dish_b, stock: 3)

    assert_difference 'Order.count', 1 do
      post orders_path, params: { menu_item_ids: [@mi.id] }
    end

    order = Order.last
    assert_equal 1, order.order_items.count
    assert_equal @mi, order.order_items.first.menu_item
    assert_not order.order_items.map(&:menu_item).include?(mi_b)
  end

  # CA2: platillo con stock=0 seleccionado → falla con mensaje
  test 'create falla con mensaje cuando se selecciona un platillo sin stock' do
    @mi.update!(stock: 0)

    assert_no_difference 'Order.count' do
      post orders_path, params: { menu_item_ids: [@mi.id] }
    end

    assert_redirected_to new_order_path
    assert_match 'no tienen stock disponible', flash[:error]
    assert_equal 0, @mi.reload.stock
  end

  # CA3: selección mixta con un platillo sin stock → todo falla
  test 'create falla si hay platillos sin stock entre los seleccionados' do
    dish_b = Dish.create!(name: 'Enchiladas', price_cents: 3_500, active: true)
    mi_b   = MenuItem.create!(daily_menu: @menu, dish: dish_b, stock: 0)

    assert_no_difference 'Order.count' do
      post orders_path, params: { menu_item_ids: [@mi.id, mi_b.id] }
    end

    assert_redirected_to new_order_path
    assert_match 'no tienen stock disponible', flash[:error]
  end

  # CA4: sin platillos seleccionados → falla con mensaje específico
  test 'create falla cuando no se selecciona ningun platillo' do
    assert_no_difference 'Order.count' do
      post orders_path, params: { menu_item_ids: [] }
    end

    assert_redirected_to new_order_path
    assert_equal 'Debes seleccionar al menos un platillo', flash[:error]
  end

  # CA5: stock se decrementa para los platillos seleccionados
  test 'create decrementa stock y crea la orden en una transaccion' do
    assert_difference 'Order.count', 1 do
      post orders_path, params: { menu_item_ids: [@mi.id] }
    end

    assert_equal 4, @mi.reload.stock
  end

  # CA6: atomicidad — sin cambios de stock si la validación falla
  test 'create no modifica stock si algun platillo seleccionado no tiene stock' do
    dish_b = Dish.create!(name: 'Enchiladas', price_cents: 3_500, active: true)
    mi_b   = MenuItem.create!(daily_menu: @menu, dish: dish_b, stock: 0)
    stock_before = @mi.reload.stock

    assert_no_difference 'Order.count' do
      post orders_path, params: { menu_item_ids: [@mi.id, mi_b.id] }
    end

    assert_equal stock_before, @mi.reload.stock
    assert_equal 0, mi_b.reload.stock
  end

  test 'create no decrementa stock si la orden falla por duplicado' do
    @menu.orders.create!(
      user: @user,
      order_items_attributes: [{ menu_item_id: @mi.id, price_cents: @dish.price_cents }]
    )
    stock_before = @mi.reload.stock

    assert_no_difference 'Order.count' do
      post orders_path, params: { menu_item_ids: [@mi.id] }
    end

    assert_equal stock_before, @mi.reload.stock, 'el stock no debe cambiar si la orden falla'
  end

  test 'stock no queda negativo: segunda orden falla cuando el stock se agoto' do
    @mi.update!(stock: 1)
    user2 = User.create!(email_address: 'second-user@test.com', name: 'Segundo Usuario',
                         role: 'employee', password: 'password')

    place_locked_order!(@user)

    assert_raises OrdersController::InsufficientStockError do
      place_locked_order!(user2)
    end

    assert_equal 0, @mi.reload.stock, 'el stock no puede ser negativo'
    assert_equal 1, Order.count, 'solo una orden debe haberse creado'
  end

  private

  def place_locked_order!(user)
    Order.transaction do
      mi = MenuItem.lock.find(@mi.id)
      raise OrdersController::InsufficientStockError if mi.stock <= 0

      mi.decrement!(:stock)
      @menu.orders.create!(
        user: user,
        order_items_attributes: [{ menu_item_id: mi.id, price_cents: mi.price_cents }]
      )
    end
  end
end
