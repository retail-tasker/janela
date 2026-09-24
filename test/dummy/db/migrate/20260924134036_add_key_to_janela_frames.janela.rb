# This migration comes from janela (originally 20260924000002)
class AddKeyToJanelaFrames < ActiveRecord::Migration[8.0]
  def change
    # The host's own name for a frame, so it finds one of an owner's several
    # from code (ADR 041). Janela reads it only in Frame.for.
    add_column :janela_frames, :key, :string
    # One frame per owner and key. Frames without a key, every one an analyst
    # makes, are not constrained: a null is never equal to another.
    add_index :janela_frames, [ :owner_type, :owner_id, :key ], unique: true
  end
end
