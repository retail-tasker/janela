# What each page tells a search engine or a link preview about itself (ADR 060).
module SeoHelper
  SITE_NAME = "Janela".freeze
  SITE_DESCRIPTION = "Janela is a Rails gem for cross-filtering dashboards. Declare measures and dimensions " \
                     "on your ActiveRecord models, click any value, and every pane re-scopes around it.".freeze

  def page_title
    content_for(:title).presence || SITE_NAME
  end

  def page_description
    content_for(:description).presence || SITE_DESCRIPTION
  end

  # The page's own path and nothing after it: a filter, a campaign tag and a
  # period are the same page, and one address for it is what a search engine
  # should be told.
  def canonical_url
    "#{request.base_url}#{request.path}"
  end

  def share_image_url
    image_url("pwa/screenshot-wide.png")
  end
end
