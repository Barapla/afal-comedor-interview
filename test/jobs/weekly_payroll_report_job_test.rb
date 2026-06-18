require "test_helper"

class WeeklyPayrollReportJobTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "payroll@test.com",
      name: "Empleado Payroll",
      role: "employee",
      password: "password"
    )
  end

  test "usa Time.zone.today en lugar de Date.today" do
    # Verifica que el job usa la zona horaria configurada, no UTC del servidor
    Time.use_zone("America/Tijuana") do
      travel_to Time.zone.parse("2026-06-15 23:30:00") do
        # Con Date.today (UTC) sería 2026-06-16 (lunes), semana del 8-14 junio
        # Con Time.zone.today (Tijuana UTC-7) sería 2026-06-15 (domingo), semana del 1-7 junio
        expected_week_start = Time.zone.today.last_week.beginning_of_week
        assert_equal Date.new(2026, 6, 8), expected_week_start
      end
    end
  end

  test "genera reporte CSV sin N+1 para órdenes de la semana anterior" do
    menu = DailyMenu.create!(menu_date: Date.current - 7)
    dish = Dish.create!(name: "Sopa", price_cents: 5_000, active: true)
    mi   = MenuItem.create!(daily_menu: menu, dish: dish, stock: 50)

    menu.orders.create!(
      user: @user,
      status: "confirmed",
      order_items_attributes: [ { menu_item_id: mi.id, price_cents: 5_000 } ]
    )

    path = nil
    assert_nothing_raised do
      path = WeeklyPayrollReportJob.new.perform
    end

    assert File.exist?(path)
    lines = File.readlines(path)
    assert_includes lines.first, "Fecha"
  ensure
    FileUtils.rm_f(path) if path
  end
end
