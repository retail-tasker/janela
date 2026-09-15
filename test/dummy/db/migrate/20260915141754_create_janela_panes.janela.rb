# This migration comes from janela (originally 20260916000002)
class CreateJanelaPanes < ActiveRecord::Migration[8.0]
  def change
    create_table :janela_panes do |t|
      # The composite index below is the one a frame's panes are read by, so
      # references adds none of its own.
      t.references :frame, null: false, index: false, foreign_key: { to_table: :janela_frames }
      t.integer :position, null: false
      t.integer :span, null: false, default: 1
      # A model's route key, the same identifier a pane URL carries (ADR 005).
      t.string :model, null: false
      t.string :measure, null: false
      t.string :dimension
      t.string :renderer, null: false, default: "table"
      t.string :granularity
      t.integer :limit
      t.string :title
      t.timestamps
    end

    add_index :janela_panes, [ :frame_id, :position ]
  end
end
