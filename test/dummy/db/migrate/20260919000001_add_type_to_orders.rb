class AddTypeToOrders < ActiveRecord::Migration[8.1]
  def change
    # Nullable because most of a shop's orders are the ordinary kind: a row
    # with no type is an Order, which is what single table inheritance means
    # by the base class. Indexed because every query on a subclass carries the
    # type condition ActiveRecord adds for it.
    add_column :orders, :type, :string
    add_index :orders, :type
  end
end
