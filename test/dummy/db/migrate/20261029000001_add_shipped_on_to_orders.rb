# A second date on an order, so the demo has two time dimensions over one
# table: placed_on for every order and shipped_on for the ones that went out.
# Nullable on purpose: an order that has not shipped has no date, and a series
# bucketed by this column counts only the rows that have one (ADR 062).
class AddShippedOnToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :shipped_on, :date
  end
end
