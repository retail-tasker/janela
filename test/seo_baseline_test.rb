require "test_helper"

# ADR 060: the demo says what each page is, and keeps crawlers off the pages
# that are one dashboard under unbounded filters.
class SeoBaselineTest < ActionDispatch::IntegrationTest
  test "every page has a language, a description, a canonical link and a link preview" do
    get "/docs/agents", params: { utm_source: "newsletter" }

    assert_select "html[lang=en]"
    assert_select "meta[name=description][content]"
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/docs/agents"
    assert_select "meta[property='og:title'][content=?]", "Giving an Agent Access to Janela"
    assert_select "meta[property='og:type'][content=website]"
    assert_select "meta[property='og:url'][content=?]", "http://www.example.com/docs/agents"
    assert_select "meta[property='og:image'][content*='.png']"
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
  end

  test "a documentation page describes itself with its own first paragraph, not the site's" do
    get "/docs/agents"
    agents = css_select("meta[name=description]").first["content"]

    get root_path
    home = css_select("meta[name=description]").first["content"]

    assert_match(/arrange a dashboard|tools instead/i, agents)
    assert_not_equal home, agents
    assert_operator agents.length, :<=, 160
    assert_no_match(/[`*\[\]]/, agents, "markdown should not leak into a description")
  end

  test "a page with nothing of its own to say still gets the site's description" do
    get gallery_path

    assert_select "meta[name=description][content]"
  end

  test "the canonical link of a filtered dashboard is the unfiltered page" do
    get orders_path(q: { status_eq: "paid" })

    assert_select "link[rel=canonical][href=?]", "http://www.example.com/orders"
  end

  test "every page that is indexed has exactly one h1" do
    [ root_path, the_name_path, gallery_path, docs_path, "/docs/agents", visits_path, vitral_path ].each do |path|
      get path
      assert_select "h1", { count: 1 }, "#{path} should have exactly one h1"
    end
  end

  test "robots.txt names the sitemap and keeps crawlers off the filtered dashboards" do
    get "/robots.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_includes response.body, "Sitemap: http://www.example.com/sitemap.xml"
    %w[/dashboards /snapshots /frames].each { |path| assert_includes response.body, "Disallow: #{path}" }
    assert_no_match(/Disallow: \/\s*$/, response.body, "the whole site must not be disallowed")
  end

  test "the sitemap lists the pages worth finding and none of the filtered ones" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    locs = Nokogiri::XML(response.body).remove_namespaces!.css("url > loc").map(&:text)

    assert_includes locs, "http://www.example.com/"
    assert_includes locs, "http://www.example.com/docs/agents"
    assert_includes locs, "http://www.example.com/name"
    assert_includes locs, "http://www.example.com/gallery"
    assert_includes locs, "http://www.example.com/visits"
    assert locs.any? { |loc| loc.match?(%r{/docs/\d{3}-}) }, "the decisions should be listed"
    assert_equal locs, locs.uniq
    assert locs.none? { |loc| loc.include?("/dashboards") || loc.include?("?") || loc.end_with?("/docs/naming") }
  end

  test "robots.txt and the sitemap are not counted as page views" do
    assert_no_difference -> { PageView.count } do
      get "/robots.txt"
      get "/sitemap.xml"
    end
  end
end
