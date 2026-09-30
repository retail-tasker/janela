# This migration comes from janela (originally 20260930000001)
class AddHeightToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # How tall a bar or line chart is drawn, one of five steps (ADR 047). Null
    # is what every existing pane is: unset, and drawn exactly as before.
    add_column :janela_panes, :height, :integer
  end
end
