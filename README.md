# Comedor AFAL

Aplicación Rails 8 que modela el comedor interno de Grupo AFAL: empleados ordenan del menú del día, la cocina prepara las porciones y nómina descuenta lo que no cubre el subsidio diario.

> Datos 100% sintéticos. No contiene información real de empleados, proveedores ni nómina.

---

## Requisitos

- Docker Desktop (macOS / Windows) o Docker Engine + Compose (Linux).
- Nada más. No necesitas Ruby ni PostgreSQL instalados localmente.

---

## Setup

```bash
git clone <url-del-repo> afal-comedor
cd afal-comedor
docker compose up --build
```

Espera a ver `Listening on http://0.0.0.0:3000`. En otra terminal:

```bash
docker compose exec web bin/rails db:seed
```

Abre **http://localhost:3000** y entra con cualquiera de estos usuarios:

| Rol      | Correo                | Contraseña |
|----------|-----------------------|------------|
| Admin    | `admin@afal.test`     | `password` |
| Chef     | `chef@afal.test`      | `password` |
| Empleado | `empleado@afal.test`  | `password` |

---

## Comandos comunes

```bash
docker compose exec web bin/rails console       # consola Rails
docker compose exec web bin/rails test          # corre la suite de tests
docker compose exec web bin/rails db:migrate    # corre migraciones pendientes
docker compose exec web bin/rails db:reset      # tira y recrea la DB con seeds
docker compose logs -f web                      # log del server
docker compose exec web bash                    # shell dentro del contenedor
docker compose down                             # apaga los contenedores
docker compose down -v                          # apaga y borra el volumen de Postgres
```

---

## Troubleshooting

- **Puerto 3000 ocupado**: edita `docker-compose.yml` y cambia `3000:3000` a `3001:3000`.
- **DB en estado raro**: `docker compose down -v` borra los volúmenes y empezamos limpio.
- **Cambios en `Gemfile`**: `docker compose build web` para reinstalar gems.
- **Windows / WSL — `bad interpreter` o `\r: not found`**: line endings CRLF en scripts bash. Asegúrate de tener `core.autocrlf=input` antes de clonar, o ejecuta `git config core.autocrlf input && git rm --cached -r . && git reset --hard`. El `.gitattributes` del repo fuerza LF, pero un clone previo pudo haberlo roto.
- **Linux nativo — `permission denied` en `bin/docker-entrypoint`**: dale permiso de ejecución con `chmod +x bin/docker-entrypoint` y rebuild.
- **Docker Desktop no inicia**: en Windows requiere WSL2 + virtualización habilitada en BIOS. En macOS, espera ver el ícono de la ballena en la barra de menú antes de correr `docker compose up`.

---

## Dominio

- **User**: empleado del comedor. Roles: `admin`, `chef`, `employee`.
- **Dish**: catálogo de platillos. Precio en centavos.
- **DailyMenu**: el menú de un día específico. Único por fecha.
- **MenuItem**: platillo dentro de un menú con su `stock` disponible.
- **Order**: pedido de un empleado para un día. Una orden por empleado por día.
- **OrderItem**: cada platillo dentro de una orden.

### Reglas de negocio

- Subsidio diario por empleado: **$100 MXN** (10 000 centavos). El subsidio cubre hasta ese monto del consumo del empleado.
- Total a descontar de nómina = `items_total − subsidio_aplicado` (no puede ser negativo).
- Un empleado puede pedir solo una vez por día (validación de unicidad).
- Stock por platillo: al confirmar una orden, baja el stock disponible.

### Funcionalidad implementada

- **Empleado**: ver menú del día, crear pedido, ver historial de pedidos, ver total a descontar.
- **Chef**: tablero con porciones a preparar y stock restante por platillo.
- **Admin**: CRUD de platillos, creación de menús del día, ajuste de stock por menú.
- **Reporte semanal de nómina**: `WeeklyPayrollReportJob` genera un CSV con lo que se debe descontar de cada empleado en la semana pasada. Se guarda en `tmp/payroll_reports/`.

---

## Estructura del repo

```
app/
  controllers/        # OrdersController, Admin::*, Chef::*
  models/             # User, Dish, DailyMenu, MenuItem, Order, OrderItem
  jobs/               # WeeklyPayrollReportJob
  views/              # ERB + vanilla CSS
config/
  routes.rb
  database.yml        # parametrizado por ENV para Docker
  locales/es.yml      # locale español para fechas y números
db/
  migrate/
  seeds.rb            # idempotente
test/                 # Minitest
```

---

## Stack

- Rails 8.1, Ruby 4.0
- PostgreSQL 16
- Auth: nativa de Rails 8 (`bin/rails generate authentication`)
- Jobs: Solid Queue (DB-backed, sin Redis)
- Frontend: ERB + vanilla CSS, sin frameworks
- Tests: Minitest
