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
end
