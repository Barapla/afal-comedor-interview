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

    @dish  = Dish.create!(name: 'Tacos', price_cents: 4_000, active: true)
    @mi    = MenuItem.create!(daily_menu: @menu, dish: @dish, stock: 5)
  end

  test 'create decrementa stock y crea la orden en una transacción' do
    assert_difference 'Order.count', 1 do
      post orders_path, params: {
        order: { order_items_attributes: { '0' => { menu_item_id: @mi.id } } }
      }
    end
    assert_equal 4, @mi.reload.stock
  end

  test 'create falla cuando no hay stock disponible' do
    @mi.update!(stock: 0)
    assert_no_difference 'Order.count' do
      post orders_path, params: {
        order: { order_items_attributes: { '0' => { menu_item_id: @mi.id } } }
      }
    end
    assert_response :unprocessable_entity
    assert_equal 0, @mi.reload.stock
  end

  test 'create no decrementa stock si la orden falla por duplicado' do
    @menu.orders.create!(
      user: @user,
      order_items_attributes: [{ menu_item_id: @mi.id, price_cents: @dish.price_cents }]
    )
    stock_before = @mi.reload.stock

    assert_no_difference 'Order.count' do
      post orders_path, params: {
        order: { order_items_attributes: { '0' => { menu_item_id: @mi.id } } }
      }
    end

    assert_equal stock_before, @mi.reload.stock, 'el stock no debe cambiar si la orden falla'
  end

  test 'stock no queda negativo: segunda orden falla cuando el stock se agotó' do
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
