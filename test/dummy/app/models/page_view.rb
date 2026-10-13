# One page opened on the demo, written by RecordsPageViews and read by the
# Visits dashboard (/visits), which is a Janela frame over this model. `page` is
# controller#action, which names a screen whatever id it was opened with, and
# `path` keeps the URL without its query string, which tells one doc from
# another.
class PageView < ApplicationRecord
  FRAME = "Site visits".freeze

  validates :page, :path, :viewed_at, :viewed_on, presence: true

  janela do
    measure :views, count: true

    dimension :page
    dimension :path
    dimension :viewed_on, granularity: :day
  end

  def self.record(controller:, action:, path:)
    create!(page: "#{controller}##{action}", path: path, viewed_at: Time.current, viewed_on: Time.zone.today)
  end
end
