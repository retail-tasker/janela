class AddChannelAndExpeditedToOrders < ActiveRecord::Migration[8.1]
  def change
    # Nullable on purpose: a dimension over a column with nulls is the case in
    # issue #21, and a column added to an existing table is how nulls arrive.
    add_column :orders, :channel, :string
    add_column :orders, :expedited, :boolean, null: false, default: false
  end
end
