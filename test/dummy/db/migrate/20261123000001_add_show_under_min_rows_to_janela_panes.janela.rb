# This migration comes from janela (originally 20261123000001)
class AddShowUnderMinRowsToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # Whether a category pane lists the groups under its measure's min_rows,
    # without a value and after every group that qualified, rather than
    # leaving them out (ADR 064). Null is what every existing pane is: unset.
    add_column :janela_panes, :show_under_min_rows, :boolean
  end
end
