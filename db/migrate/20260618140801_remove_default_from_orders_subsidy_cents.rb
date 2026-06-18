# frozen_string_literal: true

class RemoveDefaultFromOrdersSubsidyCents < ActiveRecord::Migration[8.1]
  def change
    change_column_default :orders, :subsidy_cents, from: 10_000, to: nil
  end
end
