# frozen_string_literal: true

class OrderGuest < ApplicationRecord
  belongs_to :order
  belongs_to :guest

  validates :order_id, uniqueness: true
  validate :guest_not_already_ordered_today

  private

  def guest_not_already_ordered_today
    return unless order&.daily_menu_id

    existing = OrderGuest.joins(:order)
                         .where(guest_id: guest_id, orders: { daily_menu_id: order.daily_menu_id })
                         .where.not(id: id)
    errors.add(:guest_id, :taken) if existing.exists?
  end
end
