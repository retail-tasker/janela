require "test_helper"

# ADR 061: the demo speaks Brazilian Portuguese under /pt-BR, one address per
# language, and Janela itself ships English only.
class LocaleTest < ActionDispatch::IntegrationTest
  TRANSLATED = %w[/ /orders /visits].freeze

  test "English stays at the root, with no prefix on any link" do
    get "/"

    assert_select "html[lang=en]"
    assert_select "a[href='/orders']"
    assert_select "a[href^='/pt-BR']:not([hreflang=pt-BR])", false, "only the picker points at Portuguese"
  end

  test "Brazilian Portuguese is under /pt-BR, in the page and in the language attribute" do
    get "/pt-BR"

    assert_response :success
    assert_select "html[lang=pt-BR]"
    assert_select "h1", "Dashboards com filtro cruzado, nativos do Rails."
    assert_select "meta[property='og:locale'][content=pt_BR]"
  end

  test "every internal link on a Portuguese page stays in Portuguese" do
    TRANSLATED.each do |path|
      get "/pt-BR#{path == '/' ? '' : path}"

      internal = css_select("a[href^='/']").map { |a| a["href"] }.reject { |href| href.start_with?("/assets", "/rails", "/pt-BR") }
      # The picker is the one link that leaves Portuguese, and it names English.
      english = css_select("a[hreflang=en]").map { |a| a["href"] }
      assert_equal [], internal - english, "#{path}: links that dropped the prefix"
    end
  end

  test "the picker offers the other language and keeps the page and its filter" do
    get "/orders", params: { q: { status_eq: "paid" } }
    href = css_select("a[hreflang=pt-BR][lang=pt-BR]").first
    assert_equal "Português", href.text
    assert_equal({ "q" => { "status_eq" => "paid" } }, Rack::Utils.parse_nested_query(URI(href["href"]).query))
    assert_equal "/pt-BR/orders", URI(href["href"]).path

    get "/pt-BR/orders", params: { q: { status_eq: "paid" } }
    href = css_select("a[hreflang=en][lang=en]").first
    assert_equal "English", href.text
    assert_equal "/orders", URI(href["href"]).path
    assert_equal({ "q" => { "status_eq" => "paid" } }, Rack::Utils.parse_nested_query(URI(href["href"]).query))
  end

  test "the picker from the home page in Portuguese goes to the English root" do
    get "/pt-BR"

    assert_select "a[hreflang=en][href='/']"
  end

  test "an address in a language we do not have is a 404, not a locale" do
    get "/fr/orders"

    assert_response :not_found
  end

  test "Janela's own pages speak Portuguese too, and keep the prefix in their own links" do
    get "/pt-BR/dashboards"

    assert_response :success
    assert_select "h1", "Quadros"
    assert_select "a[href^='/dashboards']:not([hreflang=en])", false, "the picker is the one link that leaves Portuguese"
    assert_select "a.janela-card[href^='/pt-BR/dashboards/']"
  end

  # A route outside the prefix, the manifest, took the language as a query
  # parameter, and a test of anchors alone missed it because it is a <link>.
  test "no page puts the language in a query string anywhere, in an anchor or a link or a script" do
    [ "/pt-BR", "/pt-BR/orders", "/pt-BR/visits", "/pt-BR/gallery", "/pt-BR/dashboards" ].each do |path|
      get path

      assert_no_match(/[?&]locale=/, response.body, "#{path} carries ?locale=")
    end
  end

  test "the engine's links do not repeat the language as a query parameter" do
    get "/pt-BR/dashboards"

    hrefs = css_select("a[href]").map { |a| a["href"] }
    assert hrefs.any? { |href| href.start_with?("/pt-BR/dashboards/") }
    assert hrefs.none? { |href| href.include?("locale=") }, hrefs.grep(/locale=/).inspect
  end

  test "a pane fetches from an address in the same language, so cross-filtering stays in it" do
    get "/pt-BR/orders"

    srcs = css_select("turbo-frame[src]").map { |frame| frame["src"] }
    assert srcs.any?, "the frame page should have lazy panes"
    assert srcs.all? { |src| src.start_with?("/pt-BR/dashboards/") }, srcs.inspect
  end

  test "numbers are written the Brazilian way" do
    get "/pt-BR/dashboards/#{janela_frames(:orders).id}"

    assert_select ".janela-value-number", "$375,00"
    get "/dashboards/#{janela_frames(:orders).id}"
    assert_select ".janela-value-number", "$375.00"
  end

  test "the translated pages say so to a search engine, in both directions" do
    get "/orders"
    assert_select "link[rel=alternate][hreflang=en][href=?]", "http://www.example.com/orders"
    assert_select "link[rel=alternate][hreflang=pt-BR][href=?]", "http://www.example.com/pt-BR/orders"
    assert_select "link[rel=alternate][hreflang=x-default][href=?]", "http://www.example.com/orders"

    get "/pt-BR/orders"
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/pt-BR/orders"
    assert_select "link[rel=alternate][hreflang=en][href=?]", "http://www.example.com/orders"
  end

  test "a page that is still English in Portuguese says so, and points search engines at the English one" do
    get "/pt-BR/gallery"

    assert_response :success
    assert_select ".locale-notice", /ainda está em inglês/
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/gallery"
    assert_select "link[rel=alternate][hreflang]", false

    get "/gallery"
    assert_select ".locale-notice", false
  end

  # Rails' Portuguese list connector is " e ". A page that is still English must not
  # let it into an English sentence ("doughnut e pie").
  test "an English page under /pt-BR keeps its English prose whole" do
    get "/pt-BR/gallery"

    assert_no_match(/\b(doughnut|year|label_desc) e \w+/, response.body.gsub(/<[^>]+>/, " "))
    assert_match(/doughnut,? and pie/, response.body.gsub(/<[^>]+>/, " "))
  end

  test "the sitemap lists each translated page in both languages and robots keeps the Portuguese dashboards out" do
    get "/sitemap.xml"
    locs = Nokogiri::XML(response.body).remove_namespaces!.css("url > loc").map(&:text)

    %w[/pt-BR /pt-BR/orders /pt-BR/visits].each { |path| assert_includes locs, "http://www.example.com#{path}" }
    assert_not_includes locs, "http://www.example.com/pt-BR/gallery", "an untranslated page is not a second page"

    get "/robots.txt"
    %w[/pt-BR/dashboards /pt-BR/snapshots /pt-BR/frames].each { |path| assert_includes response.body, "Disallow: #{path}" }
  end

  test "a Portuguese page view is recorded at its own address" do
    get "/pt-BR/orders"

    assert_equal "/pt-BR/orders", PageView.order(:id).last.path
  end

  # A word the Portuguese file lacks falls back to English rather than showing a
  # key, which is kind to a reader and hides a gap from us. So the gap is looked
  # for here, in the files, instead of on a page.
  test "the Portuguese files have every key the English ones have" do
    files = lambda do |locale|
      Dir[Rails.root.join("config/locales/*.yml"), Janela::Engine.root.join("config/locales/*.yml")].sort.each_with_object({}) do |path, merged|
        merged.deep_merge!(YAML.load_file(path)[locale.to_s] || {})
      end
    end
    flatten = lambda do |hash, prefix = nil|
      hash.flat_map { |key, value| value.is_a?(Hash) ? flatten.call(value, [ prefix, key ].compact.join(".")) : [ [ prefix, key ].compact.join(".") ] }
    end
    # Plural forms differ by language, so compare the key without them.
    plain = ->(keys) { keys.map { |key| key.sub(/\.(zero|one|two|few|many|other)\z/, "") }.uniq.sort }
    english = plain.call(flatten.call(files.call(:en)))
    portuguese = plain.call(flatten.call(files.call("pt-BR")))

    assert_equal [], english - portuguese, "keys English has and Portuguese lacks"
  end
end
