class AddValueLabelsToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # Whether a bar chart draws each bar's value on the bar (ADR 054). Null is
    # what every existing pane is: unset, and drawn exactly as before.
    add_column :janela_panes, :value_labels, :boolean
  end
end
