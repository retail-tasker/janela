class AddOwnerToJanelaSnapshots < ActiveRecord::Migration[8.0]
  def change
    # Janela never reads the owner. It is here so a host's Pundit Scope has
    # something to filter a snapshot on, the same as a frame's (ADR 033).
    # Nullable, because a snapshot nobody owns is invisible to a policy that
    # filters on one, which is the safe direction to fail.
    add_reference :janela_snapshots, :owner, polymorphic: true, null: true
  end
end
