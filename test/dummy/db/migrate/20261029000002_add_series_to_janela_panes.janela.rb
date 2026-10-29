# This migration comes from janela (originally 20261029000001)
class AddSeriesToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # A running total of a time pane's measure, and up to three more series
    # drawn beside it (ADR 062). Null is what every existing pane is: unset,
    # and drawn exactly as before.
    add_column :janela_panes, :cumulative, :boolean
    add_column :janela_panes, :series, :json
  end
end
