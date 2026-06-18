# frozen_string_literal: true

require 'test_helper'

class GuestTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: 'guest-model@test.com', name: 'Test', role: 'employee', password: 'password')
    @menu = DailyMenu.create!(menu_date: Date.current + 60)
    @order = @menu.orders.create!(user: @user)
  end

  test 'invitado sin nombre no es válido' do
    guest = @order.guests.build(note: 'nota sin nombre')
    assert_not guest.valid?
    assert guest.errors[:name].any?
  end

  test 'invitado con nombre es válido' do
    guest = @order.guests.build(name: 'Invitado Uno')
    assert guest.valid?
  end

  test 'invitado con nombre y nota es válido' do
    guest = @order.guests.build(name: 'Invitado Uno', note: 'Alérgico a nueces')
    assert guest.valid?
  end

  test 'nota vacía es válida' do
    guest = @order.guests.build(name: 'Invitado Uno', note: '')
    assert guest.valid?
  end

  test 'nota que supera 500 caracteres no es válida' do
    guest = @order.guests.build(name: 'Invitado Uno', note: 'x' * 501)
    assert_not guest.valid?
    assert guest.errors[:note].any?
  end

  test 'nota de exactamente 500 caracteres es válida' do
    guest = @order.guests.build(name: 'Invitado Uno', note: 'x' * 500)
    assert guest.valid?
  end
end
