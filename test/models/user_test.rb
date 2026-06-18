require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal "downcased@example.com", user.email_address
  end

  test "role must be in ROLES" do
    user = User.new(email_address: "x@y.com", name: "X", password: "password", role: "godmode")
    assert_not user.valid?
    assert_includes user.errors[:role], "no está incluido en la lista"
  end

  test "role helpers" do
    admin = User.new(role: "admin")
    chef  = User.new(role: "chef")
    emp   = User.new(role: "employee")

    assert admin.admin?
    assert chef.chef?
    assert emp.employee?
  end

  test "requiere email_address presente" do
    user = User.new(name: "Test", role: "employee", password: "password", email_address: "")
    assert_not user.valid?
    assert user.errors[:email_address].any?, "debe tener errores de email"
  end

  test "rechaza email con formato inválido" do
    user = User.new(name: "Test", role: "employee", password: "password", email_address: "no-es-un-email")
    assert_not user.valid?
    assert user.errors[:email_address].any?
  end

  test "acepta email con formato válido" do
    user = User.new(name: "Test", role: "employee", password: "password", email_address: "valido@ejemplo.com")
    assert user.valid?
  end

  test "rechaza email duplicado a nivel de modelo" do
    User.create!(name: "Primero", role: "employee", password: "password", email_address: "dup-user@ejemplo.com")
    user2 = User.new(name: "Segundo", role: "employee", password: "password", email_address: "dup-user@ejemplo.com")
    assert_not user2.valid?
    assert user2.errors[:email_address].any?
  end
end
