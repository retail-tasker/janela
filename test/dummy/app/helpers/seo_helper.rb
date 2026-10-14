# What each page tells a search engine or a link preview about itself (ADR 060).
module SeoHelper
  SITE_NAME = "Janela".freeze

  def page_title
    content_for(:title).presence || SITE_NAME
  end

  def page_description
    content_for(:description).presence || t("seo.description")
  end

  # The page's own path and nothing after it: a filter, a campaign tag and a
  # period are the same page, and one address for it is what a search engine
  # should be told.
  # A page that is not translated has one address worth indexing, the English
  # one, so its Portuguese twin points there rather than competing with it
  # (ADR 061).
  def canonical_url
    path = I18n.locale == :en || translated_page? ? request.path : path_in(:en, query: false)
    "#{request.base_url}#{path}"
  end

  def share_image_url
    image_url("pwa/screenshot-wide.png")
  end
end
