# frozen_string_literal: true

require 'test_helper'

class OrdersControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
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

  # CA7: menu_item_ids de otro menú deben ser ignorados
  test 'create ignora menu_item_ids que no pertenecen al menu de hoy' do
    otro_menu = DailyMenu.create!(menu_date: Date.current - 1.day)
    mi_otro = MenuItem.create!(daily_menu: otro_menu, dish: @dish, stock: 5)
    assert_no_difference('Order.count') { post orders_path, params: { menu_item_ids: [mi_otro.id] } }
    assert_redirected_to new_order_path
    assert_match 'no pertenecen al menú de hoy', flash[:error]
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

  # CA1-invitados: pedido con 2 invitados válidos crea 2 registros Guest asociados
  test 'create con invitados válidos crea pedido con registros de invitados' do
    assert_difference 'Order.count', 1 do
      assert_difference 'Guest.count', 2 do
        post orders_path, params: {
          menu_item_ids: [@mi.id],
          guests: [
            { name: 'Visitante Uno', note: '', menu_item_ids: [@mi.id] },
            { name: 'Visitante Dos', note: 'VIP', menu_item_ids: [@mi.id] }
          ]
        }
      end
    end

    order = Order.last
    assert_equal 2, order.guests.count
  end

  # CA2-invitados: cada invitado tiene sus propios platillos registrados
  test 'create con invitados registra los platillos por invitado' do
    dish_b = Dish.create!(name: 'Enchiladas', price_cents: 3_500, active: true)
    mi_b   = MenuItem.create!(daily_menu: @menu, dish: dish_b, stock: 5)

    assert_difference 'GuestOrderItem.count', 2 do
      post orders_path, params: {
        menu_item_ids: [@mi.id],
        guests: [
          { name: 'Inv A', menu_item_ids: [@mi.id] },
          { name: 'Inv B', menu_item_ids: [mi_b.id] }
        ]
      }
    end

    order = Order.last
    assert_equal [@mi.id], order.guests.find_by(name: 'Inv A').menu_items.pluck(:id)
    assert_equal [mi_b.id], order.guests.find_by(name: 'Inv B').menu_items.pluck(:id)
  end

  # CA3-invitados: stock 3, empleado + 3 invitados seleccionan el mismo platillo → rechazado
  test 'create falla si stock es insuficiente para empleado mas invitados' do
    @mi.update!(stock: 3)

    assert_no_difference 'Order.count' do
      post orders_path, params: {
        menu_item_ids: [@mi.id],
        guests: [
          { name: 'Inv 1', menu_item_ids: [@mi.id] },
          { name: 'Inv 2', menu_item_ids: [@mi.id] },
          { name: 'Inv 3', menu_item_ids: [@mi.id] }
        ]
      }
    end

    assert_redirected_to new_order_path
    assert_match 'no tienen stock disponible', flash[:error]
    assert_equal 3, @mi.reload.stock
  end

  # CA4-invitados: stock 5, empleado + 2 invitados seleccionan el mismo platillo → stock baja 3
  test 'create descuenta stock por persona que selecciona cada platillo' do
    @mi.update!(stock: 5)

    assert_difference 'Order.count', 1 do
      post orders_path, params: {
        menu_item_ids: [@mi.id],
        guests: [
          { name: 'Inv 1', menu_item_ids: [@mi.id] },
          { name: 'Inv 2', menu_item_ids: [@mi.id] }
        ]
      }
    end

    assert_equal 2, @mi.reload.stock
  end

  # CA4b-invitados: invitado elige platillo distinto → solo ese stock baja
  test 'create descuenta stock independiente por platillo de cada persona' do
    dish_b = Dish.create!(name: 'Enchiladas', price_cents: 3_500, active: true)
    mi_b   = MenuItem.create!(daily_menu: @menu, dish: dish_b, stock: 5)

    post orders_path, params: {
      menu_item_ids: [@mi.id],
      guests: [{ name: 'Inv 1', menu_item_ids: [mi_b.id] }]
    }

    assert_equal 4, @mi.reload.stock
    assert_equal 4, mi_b.reload.stock
  end

  # CA5-invitados: sin invitados el flujo es idéntico al anterior
  test 'create sin invitados funciona igual que antes (compatibilidad)' do
    assert_difference 'Order.count', 1 do
      post orders_path, params: { menu_item_ids: [@mi.id] }
    end

    order = Order.last
    assert_equal 0, order.guests.count
    assert_equal 4, @mi.reload.stock
  end

  # CA6-invitados: invitado sin nombre → falla con mensaje específico
  test 'create con invitado sin nombre falla validación' do
    assert_no_difference 'Order.count' do
      post orders_path, params: {
        menu_item_ids: [@mi.id],
        guests: [{ name: '', note: 'tiene nota pero no nombre', menu_item_ids: [@mi.id] }]
      }
    end

    assert_redirected_to new_order_path
    assert_equal 'El nombre del invitado es requerido', flash[:error]
  end

  # CA7-invitados: invitado sin platillos → falla con mensaje específico
  test 'create con invitado sin platillos falla validación' do
    assert_no_difference 'Order.count' do
      post orders_path, params: {
        menu_item_ids: [@mi.id],
        guests: [{ name: 'Invitado Sin Platillo', note: '' }]
      }
    end

    assert_redirected_to new_order_path
    assert_equal 'Debes seleccionar al menos un platillo para el invitado', flash[:error]
  end

  # CA8-invitados: entrada completamente vacía de invitado es ignorada
  test 'create ignora entradas de invitado completamente vacias' do
    assert_difference 'Order.count', 1 do
      assert_no_difference 'Guest.count' do
        post orders_path, params: {
          menu_item_ids: [@mi.id],
          guests: [{ name: '', note: '', menu_item_ids: [] }]
        }
      end
    end
  end

  # CA9-invitados: detalle del pedido muestra invitados con sus platillos
  test 'show muestra los invitados del pedido con sus platillos' do
    order = @menu.orders.create!(
      user: @user,
      order_items_attributes: [{ menu_item_id: @mi.id, price_cents: @dish.price_cents }]
    )
    guest = order.guests.create!(name: 'Rodrigo Lopez')
    guest.guest_order_items.create!(menu_item: @mi, price_cents: @dish.price_cents)

    get order_path(order)

    assert_response :success
    assert_match 'Rodrigo Lopez', response.body
    assert_match 'Tacos', response.body
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
