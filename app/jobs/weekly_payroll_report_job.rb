require "csv"

class WeeklyPayrollReportJob < ApplicationJob
  queue_as :default

  REPORT_DIR = Rails.root.join("tmp", "payroll_reports")

  def perform
    week_start = Date.today.last_week.beginning_of_week
    week_end   = Date.today.last_week.end_of_week
    range = week_start..week_end

    FileUtils.mkdir_p(REPORT_DIR)
    path = REPORT_DIR.join("payroll_#{week_start}.csv")

    grouped = Order.where(created_at: range).group_by { |o| o.created_at.to_date }

    CSV.open(path, "w") do |csv|
      csv << [ "Fecha", "Empleado", "Total a descontar (cents)" ]
      grouped.sort.each do |date, orders|
        orders.each do |order|
          csv << [ date.iso8601, order.user.name, order.amount_due_cents ]
        end
      end
    end

    Rails.logger.info "Payroll report written to #{path}"
    path.to_s
  end
end
