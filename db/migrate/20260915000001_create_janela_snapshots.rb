class CreateJanelaSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :janela_snapshots do |t|
      t.string :name, null: false
      t.datetime :taken_at, null: false
      t.json :filters, null: false
      t.json :panes, null: false
      t.timestamps
    end

    add_index :janela_snapshots, :taken_at
  end
end
