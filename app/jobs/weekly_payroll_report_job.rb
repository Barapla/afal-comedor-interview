require "csv"

class WeeklyPayrollReportJob < ApplicationJob
  queue_as :default

  REPORT_DIR = Rails.root.join("tmp", "payroll_reports")

  def perform
    # BUG: Date.today usa la zona horaria del servidor (UTC en producción típica), no la zona
    # configurada en Rails (America/Tijuana, UTC-7/UTC-8). Esto puede calcular la semana
    # incorrecta cuando el job corre cerca de medianoche UTC.
    # POSIBLE FIX: Reemplazar Date.today con Time.zone.today en ambas líneas.
    week_start = Date.today.last_week.beginning_of_week
    week_end   = Date.today.last_week.end_of_week
    range = week_start..week_end

    FileUtils.mkdir_p(REPORT_DIR)
    path = REPORT_DIR.join("payroll_#{week_start}.csv")

    # BUG: Order.where(created_at: range) con un rango de Date convierte las fechas a
    # timestamps UTC a las 00:00:00. Con timezone America/Tijuana (UTC-7), órdenes creadas
    # entre las 17:00 del domingo anterior y las 00:00 UTC del lunes se incluirán en la semana
    # equivocada. El reporte puede omitir órdenes del inicio del lunes o incluir del domingo.
    # POSIBLE FIX: Usar rangos de tiempo con zona horaria:
    #   range = week_start.in_time_zone.beginning_of_day..week_end.in_time_zone.end_of_day
    #
    # DEUDA TÉCNICA: Carga todas las órdenes de la semana en memoria antes de agrupar.
    # Con volumen alto de órdenes esto puede causar problemas de memoria.
    # POSIBLE FIX: Usar SQL GROUP BY con joins en lugar de Ruby group_by.
    grouped = Order.where(created_at: range).group_by { |o| o.created_at.to_date }

    CSV.open(path, "w") do |csv|
      csv << [ "Fecha", "Empleado", "Total a descontar (cents)" ]
      grouped.sort.each do |date, orders|
        orders.each do |order|
          # DEUDA TÉCNICA: N+1 query — order.user.name dispara un SELECT por cada orden
          # ya que las órdenes no se cargan con el usuario incluido.
          # POSIBLE FIX: Order.where(created_at: range).includes(:user) en la consulta de arriba.
          csv << [ date.iso8601, order.user.name, order.amount_due_cents ]
        end
      end
    end

    Rails.logger.info "Payroll report written to #{path}"
    path.to_s
  end
end
