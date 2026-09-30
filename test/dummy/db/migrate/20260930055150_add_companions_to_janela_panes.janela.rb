# This migration comes from janela (originally 20260930000003)
class AddCompanionsToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # Measures and dimensions a table pane draws as columns beside its label
    # (ADR 051), by the names the model declared them under. Null is what
    # every existing pane is: none, and drawn exactly as before.
    add_column :janela_panes, :companions, :json
  end
end
