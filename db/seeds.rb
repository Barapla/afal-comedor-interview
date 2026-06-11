# Seeds del Comedor AFAL.
# Idempotente: puedes correr `bin/rails db:seed` varias veces sin duplicar datos.
# Datos 100% sintéticos. No usar correos ni nombres reales de personas.

puts "Sembrando usuarios…"

users_spec = [
  { email_address: "admin@afal.test",     name: "Ana Admin",      role: "admin" },
  { email_address: "chef@afal.test",      name: "Carlos Chef",    role: "chef" },
  { email_address: "empleado@afal.test",  name: "Esteban Pérez",  role: "employee" },
  { email_address: "empleada2@afal.test", name: "Elena Ruiz",     role: "employee" },
  { email_address: "empleado3@afal.test", name: "Eduardo López",  role: "employee" }
]

users_spec.each do |spec|
  User.find_or_create_by!(email_address: spec[:email_address]) do |u|
    u.name = spec[:name]
    u.role = spec[:role]
    u.password = "password"
  end
end

puts "Sembrando platillos…"

dishes_spec = [
  { name: "Pollo con mole",      price_cents: 6500, description: "Pollo en mole poblano con arroz." },
  { name: "Carne asada",         price_cents: 8500, description: "Arrachera con frijoles charros." },
  { name: "Chiles rellenos",     price_cents: 6000, description: "Poblanos rellenos de queso." },
  { name: "Ensalada del chef",   price_cents: 5500, description: "Pollo, lechuga, jitomate, aderezo." },
  { name: "Sopa de tortilla",    price_cents: 4500, description: "Caldo de jitomate con tortilla frita." }
]

dishes_spec.each do |spec|
  Dish.find_or_create_by!(name: spec[:name]) do |d|
    d.price_cents = spec[:price_cents]
    d.description = spec[:description]
    d.active      = true
  end
end

puts "Sembrando menú de hoy…"

today_menu = DailyMenu.find_or_create_today!

Dish.active.limit(4).each do |dish|
  MenuItem.find_or_create_by!(daily_menu: today_menu, dish: dish) do |mi|
    mi.stock = 25
  end
end

puts "Sembrando órdenes históricas (para el reporte semanal)…"

# Reservamos un empleado para la "orden trampa" cerca de medianoche.
# El resto sirve para el grueso del reporte.
all_employees = User.where(role: "employee").to_a
trap_user     = User.find_by!(email_address: "empleado3@afal.test")
regular       = all_employees - [ trap_user ]

last_week_dates = (Date.current.last_week.beginning_of_week..Date.current.last_week.end_of_week).to_a

last_week_dates.each do |date|
  dm = DailyMenu.find_or_create_by!(menu_date: date)
  Dish.active.limit(3).each do |dish|
    MenuItem.find_or_create_by!(daily_menu: dm, dish: dish) { |mi| mi.stock = 25 }
  end

  regular.sample(1).each do |emp|
    next if dm.orders.exists?(user: emp)

    order = dm.orders.create!(user: emp)
    dm.menu_items.sample(1).each do |mi|
      order.order_items.create!(menu_item: mi, price_cents: mi.price_cents)
    end
    # created_at al mediodía Tijuana — siempre cae en el mismo día sin importar la zona.
    order.update_columns(created_at: date.in_time_zone.change(hour: 13))
  end
end

# Orden "trampa" cerca de medianoche hora Tijuana — para reproducir Bug 2.
# Domingo 23:30 Tijuana = Lunes 06:30 UTC. Con el bug, esta orden cae en
# la semana siguiente o se pierde del reporte.
trap_date = Date.current.last_week.end_of_week
trap_menu = DailyMenu.find_or_create_by!(menu_date: trap_date)
Dish.active.limit(1).each do |dish|
  MenuItem.find_or_create_by!(daily_menu: trap_menu, dish: dish) { |mi| mi.stock = 25 }
end

unless trap_menu.orders.exists?(user: trap_user)
  trap_order = trap_menu.orders.create!(user: trap_user)
  trap_menu.menu_items.first(1).each do |mi|
    trap_order.order_items.create!(menu_item: mi, price_cents: mi.price_cents)
  end
  trap_order.update_columns(created_at: trap_date.in_time_zone.change(hour: 23, min: 30))
end

puts "Listo. Usuarios de prueba:"
puts "  admin@afal.test    / password  (admin)"
puts "  chef@afal.test     / password  (chef)"
puts "  empleado@afal.test / password  (empleado)"
