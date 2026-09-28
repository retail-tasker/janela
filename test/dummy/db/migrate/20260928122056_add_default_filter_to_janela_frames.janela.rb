# This migration comes from janela (originally 20260928000001)
class AddDefaultFilterToJanelaFrames < ActiveRecord::Migration[8.0]
  def change
    # A frame's own permanent filter (ADR 043): only a pane over
    # default_model takes it, so a frame that holds panes from more than one
    # model is never narrowed by a condition that is not about it. Present
    # or absent together; every existing frame has neither.
    add_column :janela_frames, :default_model, :string
    add_column :janela_frames, :default_where, :json
  end
end
