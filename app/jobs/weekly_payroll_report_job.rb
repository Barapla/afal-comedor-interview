# frozen_string_literal: true

require 'csv'

# Genera el informe semanal de descuentos de nómina por pedidos del comedor.
class WeeklyPayrollReportJob < ApplicationJob
  queue_as :default

  REPORT_DIR = Rails.root.join('tmp', 'payroll_reports')

  def perform
    week_start, week_end = last_week_range
    path = REPORT_DIR.join("payroll_#{week_start.to_date}.csv")
    orders = Order.where(created_at: week_start..week_end).includes(:user, order_items: [])

    FileUtils.mkdir_p(REPORT_DIR)
    write_csv(path, orders)

    Rails.logger.info "Payroll report written to #{path}"
    path.to_s
  end

  private

  def last_week_range
    last_week_date = Time.zone.today.last_week
    [
      last_week_date.beginning_of_week.in_time_zone.beginning_of_day,
      last_week_date.end_of_week.in_time_zone.end_of_day
    ]
  end

  def write_csv(path, orders)
    CSV.open(path, 'w') do |csv|
      csv << ['Fecha', 'Empleado', 'Total a descontar (cents)']
      orders.sort_by { |o| o.created_at.to_date }.each do |order|
        csv << [order.created_at.in_time_zone.to_date.iso8601, order.user.name, order.amount_due_cents]
      end
    end
  end
end
