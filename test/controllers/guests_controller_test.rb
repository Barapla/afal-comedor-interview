# frozen_string_literal: true

require "test_helper"

class GuestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "guests-ctrl@test.com",
      name: "Empleado Test",
      role: "employee",
      password: "password"
    )
    sign_in_as(@user)
    @guest = @user.guests.create!(name: "Juan Pérez")
  end

  test "index muestra los invitados del usuario autenticado" do
    get guests_path
    assert_response :success
  end

  test "new renderiza el formulario" do
    get new_guest_path
    assert_response :success
  end

  test "create registra un nuevo invitado" do
    assert_difference "Guest.count", 1 do
      post guests_path, params: { guest: { name: "Ana García" } }
    end
    assert_redirected_to guest_path(Guest.last)
  end

  test "create falla si el nombre está vacío" do
    assert_no_difference "Guest.count" do
      post guests_path, params: { guest: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "show muestra el invitado" do
    get guest_path(@guest)
    assert_response :success
  end

  test "edit renderiza el formulario de edición" do
    get edit_guest_path(@guest)
    assert_response :success
  end

  test "update modifica el invitado" do
    patch guest_path(@guest), params: { guest: { name: "Juan Actualizado" } }
    assert_redirected_to guest_path(@guest)
    assert_equal "Juan Actualizado", @guest.reload.name
  end

  test "update falla si el nombre está vacío" do
    patch guest_path(@guest), params: { guest: { name: "" } }
    assert_response :unprocessable_entity
    assert_equal "Juan Pérez", @guest.reload.name
  end

  test "destroy elimina el invitado" do
    assert_difference "Guest.count", -1 do
      delete guest_path(@guest)
    end
    assert_redirected_to guests_path
  end

  test "no puede acceder a invitados de otro usuario" do
    otro_usuario = User.create!(
      email_address: "otro@test.com",
      name: "Otro Empleado",
      role: "employee",
      password: "password"
    )
    invitado_ajeno = otro_usuario.guests.create!(name: "Invitado Ajeno")

    get guest_path(invitado_ajeno)
    assert_redirected_to guests_path
  end
end
