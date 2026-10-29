class AddIgnoreUnknownFiltersToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # Whether a pane drops a reader's filter its model cannot apply rather
    # than refusing the request (ADR 063). Null is what every existing pane
    # is: unset, and refused exactly as before.
    add_column :janela_panes, :ignore_unknown_filters, :boolean
  end
end
