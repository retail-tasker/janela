class Order < ApplicationRecord
  belongs_to :customer

  janela do
    measure :revenue, sum: :amount, prefix: "$"
    measure :orders, count: true
    measure :average_order, average: :amount, prefix: "$"
    measure :expedited_rate, ratio: :expedited
    # ADR 064: distinct customers rather than orders, and an average that is
    # shown only over at least two orders.
    measure :customers, count_distinct: :customer_id
    measure :typical_order, average: :amount, prefix: "$", min_rows: 2

    dimension :status
    dimension :region, through: :customer
    dimension :customer, through: :customer, column: :name
    dimension :channel
    dimension :placed_on, granularity: :day
    # A second date on the same table, so one pane can draw orders placed
    # beside orders shipped over the same weeks (ADR 062).
    dimension :shipped_on, granularity: :day
  end
end
