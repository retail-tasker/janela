class Order < ApplicationRecord
  belongs_to :customer

  janela do
    measure :revenue, sum: :amount
    measure :orders, count: true
    measure :average_order, average: :amount

    dimension :status
    dimension :region, through: :customer
  end
end
