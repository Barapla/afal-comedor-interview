# frozen_string_literal: true

require 'test_helper'

class OrderGuestsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: 'order-guests@test.com',
      name: 'Test Employee',
      role: 'employee',
      password: 'password'
    )
    @menu = DailyMenu.create!(menu_date: Date.current + 70)
    @dish = Dish.create!(name: 'Platillo Test', price_cents: 8_000, active: true)
    @item = MenuItem.create!(daily_menu: @menu, dish: @dish, stock: 10)
  end

  # CA5: sin invitados el flujo funciona igual al actual
  test 'sin invitados total_payroll_deduction_cents es igual a amount_due_cents' do
    order = @menu.orders.create!(
      user: @user,
      subsidy_cents: 5_000,
      order_items_attributes: [{ menu_item_id: @item.id, price_cents: @dish.price_cents }]
    )

    assert_equal 3_000, order.amount_due_cents
    assert_equal 0, order.guests_total_cents
    assert_equal 3_000, order.total_payroll_deduction_cents
  end

  # CA2: subsidio solo aplica al empleado, invitados pagan precio completo
  test 'subsidio solo aplica al empleado, invitados pagan precio completo' do
    order = @menu.orders.create!(
      user: @user,
      subsidy_cents: 5_000,
      order_items_attributes: [{ menu_item_id: @item.id, price_cents: @dish.price_cents }]
    )
    order.guests.create!(name: 'Invitado 1')

    # Empleado: 8000 - 5000 = 3000
    # Invitado: 1 * 8000 = 8000
    # Total: 11000
    assert_equal 8_000, order.items_total_cents
    assert_equal 3_000, order.amount_due_cents
    assert_equal 8_000, order.guests_total_cents
    assert_equal 11_000, order.total_payroll_deduction_cents
  end

  test 'múltiples invitados multiplican el costo sin subsidio' do
    order = @menu.orders.create!(
      user: @user,
      subsidy_cents: 5_000,
      order_items_attributes: [{ menu_item_id: @item.id, price_cents: @dish.price_cents }]
    )
    order.guests.create!(name: 'Invitado 1')
    order.guests.create!(name: 'Invitado 2')

    # Empleado: 8000 - 5000 = 3000
    # 2 invitados: 2 * 8000 = 16000
    # Total: 19000
    assert_equal 16_000, order.guests_total_cents
    assert_equal 19_000, order.total_payroll_deduction_cents
  end

  # CA1: sistema crea pedido con registros de invitados asociados
  test 'pedido creado con invitados tiene asociaciones correctas' do
    order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [{ menu_item_id: @item.id, price_cents: @dish.price_cents }]
    )
    order.guests.create!(name: 'Invitado A')
    order.guests.create!(name: 'Invitado B')

    assert_equal 2, order.guests.count
    assert_equal ['Invitado A', 'Invitado B'], order.guests.order(:created_at).pluck(:name)
  end

  # CA6: invitado con note vacío se guarda correctamente
  test 'invitado con note vacío se guarda sin errores' do
    order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [{ menu_item_id: @item.id, price_cents: @dish.price_cents }]
    )
    guest = order.guests.create!(name: 'Invitado Sin Nota', note: '')

    assert guest.persisted?
    assert_equal '', guest.note
  end
end
