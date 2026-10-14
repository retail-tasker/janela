# What a crawler reads before any page (ADR 060). Neither is a page a visitor
# opened, and neither is HTML, so neither is counted as a view.
class SeoController < ApplicationController
  # The engine's pages and the frame and snapshot pages are one dashboard under
  # filters that take any value, so a crawler that follows them meets an
  # unbounded number of addresses for the same thing. One way to keep them out,
  # and it is this file.
  def robots
    render plain: <<~TXT
      User-agent: *
      Disallow: /dashboards
      Disallow: /snapshots
      Disallow: /frames

      Sitemap: #{request.base_url}/sitemap.xml
    TXT
  end

  def sitemap
    @urls = [ root_url, orders_url, docs_url, gallery_url, the_name_url, visits_url, vitral_url ] +
            (Doc.catalogue.keys - Doc::UNLISTED.keys).map { |slug| doc_url(slug) }
  end
end
