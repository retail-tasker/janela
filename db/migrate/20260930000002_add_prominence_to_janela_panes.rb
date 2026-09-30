class AddProminenceToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # How prominent a single value is drawn, one of three steps (ADR 050).
    # Null is what every existing pane is: unset, and drawn exactly as before.
    add_column :janela_panes, :prominence, :integer
  end
end
