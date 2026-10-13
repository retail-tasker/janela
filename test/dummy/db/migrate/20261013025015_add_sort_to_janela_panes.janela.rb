# This migration comes from janela (originally 20261013000001)
class AddSortToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # How a category pane is ordered (ADR 055): desc, asc, label or label_desc.
    # Null is what every existing pane is: unset, and ordered exactly as before.
    add_column :janela_panes, :sort, :string
  end
end
