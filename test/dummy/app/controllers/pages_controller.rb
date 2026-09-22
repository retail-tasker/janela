# The demo's front page. Marketing copy and a small live dashboard, so the
# first thing a visitor meets is the thing itself rather than a screenshot.
class PagesController < ApplicationController
  # Seeded as a record, so its numbers are in the first response. A database
  # that has not been seeded falls back to the hand written panes in the view,
  # which is the other half of the same feature.
  def home
    @frame = Janela::Frame.find_by(name: "Revenue at a glance")
  end

  # Theming, shown rather than described: the same hooks docs/theming.md
  # lists, drawn live against this demo's own panes. A host page built from
  # the gem's helpers, like the gallery (ADR 027, ADR 036).
  def vitral
  end

  # The story of the name, told on top of the naming guide rather than beside
  # it, so the page and the file that ships in the gem say the same thing.
  def name
    @doc = Doc.find!("naming")
  end
end
