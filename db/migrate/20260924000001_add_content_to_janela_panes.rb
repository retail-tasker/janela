class AddContentToJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    # A pane can hold words instead of a query (ADR 039). Every existing row
    # is a query, which is the default.
    add_column :janela_panes, :kind, :string, null: false, default: "query"
    add_column :janela_panes, :heading, :string
    add_column :janela_panes, :body, :text
    add_column :janela_panes, :link, :string
    add_column :janela_panes, :partial, :string

    # A content pane has no query, so these are required by kind in the
    # model rather than by the column.
    change_column_null :janela_panes, :model, true
    change_column_null :janela_panes, :measure, true
  end
end
