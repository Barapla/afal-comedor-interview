# frozen_string_literal: true

class Guest < ApplicationRecord
  belongs_to :user
  has_many :order_guests, dependent: :destroy
  has_many :orders, through: :order_guests

  validates :name, presence: true
end
