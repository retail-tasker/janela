class CreateJanelaFrames < ActiveRecord::Migration[8.0]
  def change
    create_table :janela_frames do |t|
      t.string :name, null: false
      t.integer :columns, null: false, default: 3
      t.integer :gap, null: false, default: 4
      # Janela never reads the owner. It is here so a host's Pundit Scope has
      # something to filter a frame on (ADR 014).
      t.references :owner, polymorphic: true, null: true
      t.timestamps
    end
  end
end
