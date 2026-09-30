class Order < ApplicationRecord
  belongs_to :customer

  janela do
    measure :revenue, sum: :amount, prefix: "$"
    measure :orders, count: true
    measure :average_order, average: :amount, prefix: "$"
    measure :expedited_rate, ratio: :expedited

    dimension :status
    dimension :region, through: :customer
    dimension :customer, through: :customer, column: :name
    dimension :channel
    dimension :placed_on, granularity: :day
  end
end
