class Dish < ApplicationRecord
  has_many :menu_items, dependent: :restrict_with_error
  has_many :daily_menus, through: :menu_items

  validates :name, presence: true
  validates :price_cents, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }

  def price
    price_cents.to_f / 100
  end
end
