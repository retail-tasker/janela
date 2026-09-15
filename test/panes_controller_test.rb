require "test_helper"

class PanesControllerTest < ActionDispatch::IntegrationTest
  test "a pane URL reads model, measure, dimension" do
    get janela.pane_path("orders", "revenue", "status")

    assert_response :success
    assert_select "caption", "Revenue by Status"
    assert_select "td", "paid"
    assert_select "td", "300.0"
  end

  test "a pane with no dimension is the single total" do
    get janela.pane_path("orders", "revenue")

    assert_response :success
    assert_select ".janela-value .janela-value-label", "Revenue"
    assert_select ".janela-value .janela-value-number", "375.0"
  end

  test "a single value pane applies every filter" do
    get janela.pane_path("orders", "revenue", q: { status_eq: "paid" })

    assert_select ".janela-value-number", "300.0"
  end

  test "a filter on another dimension scopes the pane" do
    get janela.pane_path("orders", "revenue", "status", q: { customer_region_eq: "APAC" })

    assert_select "td", "100.0"
    assert_select "td", text: "300.0", count: 0
  end

  test "a pane ignores a filter on its own dimension but marks it pressed" do
    get janela.pane_path("orders", "revenue", "status", q: { status_eq: "paid" })

    assert_select "button[aria-pressed=true]", "paid"
    assert_select "button[aria-pressed=false]", "refunded"
  end

  test "as=bar renders a canvas carrying data and selection" do
    get janela.pane_path("orders", "revenue", "status", as: "bar", q: { status_eq: "paid" })

    assert_select "canvas[data-controller='janela--chart'][data-janela--chart-selected-value=paid]"
    assert_select "canvas[data-janela--chart-values-value='[300.0,25.0,50.0]']"
  end

  test "a scalar q parameter is ignored rather than raising" do
    get janela.pane_path("orders", "revenue", "status", q: "x")

    assert_response :success
    assert_select "td", "300.0"
  end

  test "a pane with no rows renders an empty state" do
    get janela.pane_path("orders", "revenue", "status", q: { customer_region_eq: "Mars" })

    assert_select "p.janela-empty"
  end

  test "an unknown renderer raises" do
    assert_raises(Janela::Error) { get janela.pane_path("orders", "revenue", "status", as: "pie") }
  end

  test "a model that has not declared a janela block is not addressable" do
    assert_raises(Janela::Error) { get janela.pane_path("customers", "revenue", "status") }
  end

  test "a time pane buckets by granularity and is not clickable" do
    get janela.pane_path("orders", "revenue", "placed_on", granularity: "month")

    assert_response :success
    assert_select "caption", "Revenue by Placed on per month"
    assert_select "td span", "Sep 2026"
    assert_select "td", "375.0"
    assert_select "button", count: 0
  end

  test "a time pane as a line chart carries no filter key" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line")

    assert_select "canvas[data-janela--chart-type-value=line][data-janela--chart-key-value='']"
    assert_select "canvas[data-janela--chart-labels-value=?]", %w[2026-09-01 2026-09-02 2026-09-03 2026-09-04].to_json
  end

  test "an unknown granularity raises" do
    assert_raises(Janela::Error) { get janela.pane_path("orders", "revenue", "placed_on", granularity: "fortnight") }
  end

  test "the frame id matches what the helper renders" do
    get janela.pane_path("orders", "revenue", "status", as: "bar")

    assert_select "turbo-frame#janela_orders_revenue_status_bar"
  end
end
