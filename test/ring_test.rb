require "test_helper"

# ADR 046: a doughnut and a pie are drawn on the server as inline SVG with a
# legend of real buttons. #30 assumed Chart.js and a canvas, which would have
# been blank without JavaScript and had nothing focusable behind it.
class RingTest < ActionDispatch::IntegrationTest
  test "doughnut and pie are renderers Janela offers" do
    assert_includes Janela.renderers, "doughnut"
    assert_includes Janela.renderers, "pie"
  end

  test "as=doughnut is an svg with a slice per value and no canvas" do
    get janela.pane_path("orders", "revenue", "status", as: "doughnut")

    assert_response :success
    assert_select "canvas", count: 0
    assert_select "figure.janela-pane.janela-ring > figcaption.janela-chart-title", "Revenue by Status"
    title_id = css_select("figcaption.janela-chart-title").first["id"]
    assert_select "svg.janela-ring-svg[aria-labelledby=?]", title_id
    assert_select "svg path.janela-ring-slice", count: 3
    assert_select "svg path.janela-ring-slice > title", text: "paid: $300.00"
  end

  test "a slice and its legend button toggle the same filter a table button does" do
    get janela.pane_path("orders", "revenue", "status", as: "doughnut")

    assert_select "path.janela-ring-slice[data-action='click->janela--frame#toggle'][data-janela--frame-key-param='status_in'][data-janela--frame-value-param='paid']"
    assert_select "table.janela-legend button[data-janela--frame-key-param='status_in'][data-janela--frame-value-param='paid']", "paid"
    assert_select "table.janela-legend td", "$300.00"
  end

  test "slices take the palette in the order they appear, and a legend swatch matches" do
    get janela.pane_path("orders", "revenue", "status", as: "doughnut")

    assert_select "path.janela-ring-slice:nth-of-type(1)[style*='--janela-series-1']"
    assert_select "path.janela-ring-slice:nth-of-type(2)[style*='--janela-series-2']"
    assert_select "table.janela-legend tr:nth-of-type(3) .janela-swatch[style*='--janela-series-3']"
  end

  test "colours are never cycled: the ninth category takes the neutral" do
    query = Janela::Query.new(definition: Order.janela, measure: :revenue, dimension: :status, renderer: "pie")

    assert_equal "--janela-series-8", query.series_property(7)
    assert_equal "--janela-series-other", query.series_property(8)
    assert_equal "--janela-series-other", query.series_property(40)
  end

  test "a pie has no hole and a doughnut does" do
    get janela.pane_path("orders", "revenue", "status", as: "pie")
    assert_select "svg.janela-ring-svg[data-hole='false']"

    get janela.pane_path("orders", "revenue", "status", as: "doughnut")
    assert_select "svg.janela-ring-svg[data-hole='true']"
  end

  test "the selection is shown: unselected slices are dimmed, the selected one is solid and pressed" do
    get janela.pane_path("orders", "revenue", "status", as: "doughnut", q: { status_in: [ "paid" ] })

    assert_select "path.janela-ring-slice[data-janela--frame-value-param='paid']:not(.janela-dim)"
    assert_select "path.janela-ring-slice.janela-dim", count: 2
    assert_select "table.janela-legend button[aria-pressed=true]", "paid"
    assert_select "table.janela-legend button[aria-pressed=false]", count: 2
  end

  test "a ring ignores a filter on its own dimension, like every other pane" do
    get janela.pane_path("orders", "revenue", "status", as: "doughnut", q: { status_in: [ "paid" ] })

    assert_select "path.janela-ring-slice", count: 3
  end

  test "a filter elsewhere re-scopes the ring" do
    get janela.pane_path("orders", "revenue", "status", as: "doughnut", q: { customer_region_eq: "APAC" })

    assert_select "table.janela-legend td", text: "$300.00", count: 0
  end

  test "a single slice is a whole circle, not a degenerate arc" do
    get janela.pane_path("orders", "revenue", "status", as: "doughnut", q: { customer_region_eq: "APAC", channel_eq: "web" })
    paths = css_select("path.janela-ring-slice")

    assert_predicate paths.size, :positive?
    paths.each { |path| assert_no_match(/NaN|Infinity/, path["d"]) }
  end

  # A part of a whole cannot be negative, and drawing it as one would be
  # silently wrong. Nothing raises: it is a table, and it says why.
  test "a ring over a negative value is a table that says so" do
    Order.create!(customer: Customer.first, status: "credited", amount: -80, placed_on: Date.new(2026, 9, 5))

    get janela.pane_path("orders", "revenue", "status", as: "doughnut")

    assert_response :success
    assert_select "svg", count: 0
    assert_select "table.janela-pane td", "credited"
    assert_select "p.janela-muted", /negative/
  end

  test "a zero value is left out of the ring and stays in the legend" do
    Order.create!(customer: Customer.first, status: "void", amount: 0, placed_on: Date.new(2026, 9, 5))

    get janela.pane_path("orders", "revenue", "status", as: "doughnut")

    assert_select "path.janela-ring-slice", count: 3
    assert_select "table.janela-legend button", "void"
  end

  test "a stored pane can name a doughnut and is validated against the same list" do
    frame = Janela::Frame.create!(name: "Rings")
    pane = frame.panes.new(model: "orders", measure: "revenue", dimension: "status", renderer: "doughnut")

    assert_predicate pane, :valid?
    assert_not_predicate pane, :chart?, "a ring is HTML and needs no chart runtime"
  end
end
