class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :status, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :placed_on, null: false
      t.timestamps
    end
  end
end
