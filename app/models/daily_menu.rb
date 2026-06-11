class DailyMenu < ApplicationRecord
  has_many :menu_items, dependent: :destroy
  has_many :dishes, through: :menu_items
  has_many :orders, dependent: :restrict_with_error

  validates :menu_date, presence: true, uniqueness: true

  def self.today
    find_by(menu_date: Date.current)
  end

  def self.find_or_create_today!
    find_or_create_by!(menu_date: Date.current)
  end
end
