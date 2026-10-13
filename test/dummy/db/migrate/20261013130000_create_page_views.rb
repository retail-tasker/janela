# One row per page opened on the demo, so the Visits dashboard (/visits) is
# Janela reading the demo's own traffic. Same shape as Hex's page_views: no
# cookie, no IP, no user agent kept. Nothing here says who a visitor was.
class CreatePageViews < ActiveRecord::Migration[8.1]
  def change
    create_table :page_views do |t|
      t.string   :page,      null: false
      t.string   :path,      null: false
      t.datetime :viewed_at, null: false
      # Stored rather than derived from viewed_at, so a day is a day on every
      # database and never depends on its time zone support.
      t.date     :viewed_on, null: false
    end

    add_index :page_views, %i[page viewed_on]
    add_index :page_views, :viewed_on
  end
end
