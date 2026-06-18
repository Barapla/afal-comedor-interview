require "csv"

class WeeklyPayrollReportJob < ApplicationJob
  queue_as :default

  REPORT_DIR = Rails.root.join("tmp", "payroll_reports")

  def perform
    week_start = Time.zone.today.last_week.beginning_of_week
    week_end   = Time.zone.today.last_week.end_of_week
    range = week_start.in_time_zone.beginning_of_day..week_end.in_time_zone.end_of_day

    FileUtils.mkdir_p(REPORT_DIR)
    path = REPORT_DIR.join("payroll_#{week_start}.csv")

    orders = Order.where(created_at: range).includes(:user, order_items: [])

    CSV.open(path, "w") do |csv|
      csv << [ "Fecha", "Empleado", "Total a descontar (cents)" ]
      orders.sort_by { |o| o.created_at.to_date }.each do |order|
        csv << [ order.created_at.in_time_zone.to_date.iso8601, order.user.name, order.amount_due_cents ]
      end
    end

    Rails.logger.info "Payroll report written to #{path}"
    path.to_s
  end
end
