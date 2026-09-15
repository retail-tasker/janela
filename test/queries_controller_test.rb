require "test_helper"

class QueriesControllerTest < ActionDispatch::IntegrationTest
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
    assert_select "canvas[data-janela--chart-values-value='[300.0,50.0,25.0]']"
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

  test "an unknown renderer is a 400 that names nothing internal" do
    get janela.pane_path("orders", "revenue", "status", as: "pie")

    assert_response :bad_request
    assert_select "p.janela-error", "That request is not allowed on this pane."
    assert_no_match "pie", response.body
  end

  test "a model that has not declared a janela block is a 404 that names nothing internal" do
    get janela.pane_path("customers", "revenue", "status")

    assert_response :not_found
    assert_select "p.janela-error", "There is no such pane."
    assert_no_match(/Customer|customers/, response.body)
  end

  test "an unknown measure or dimension is a 404" do
    get janela.pane_path("orders", "profit")
    assert_response :not_found

    get janela.pane_path("orders", "revenue", "colour")
    assert_response :not_found
  end

  test "a filter the allowlist rejects is a 400 that does not echo the key" do
    get janela.pane_path("orders", "revenue", q: { customer_created_at_eq: "2026-01-01" })

    assert_response :bad_request
    assert_no_match "customer_created_at_eq", response.body
  end

  test "a Turbo Frame request gets its frame back with the message inside" do
    get janela.pane_path("orders", "profit"), headers: { "Turbo-Frame" => "janela_orders_profit" }

    assert_response :not_found
    assert_select "turbo-frame#janela_orders_profit p.janela-error"
    assert_no_match "<html", response.body
  end

  test "a direct request renders the message inside Janela's own layout" do
    get janela.pane_path("orders", "profit")

    assert_select "html title"
    assert_select "p.janela-error"
    assert_select "nav", count: 0
  end

  test "a pane renders even though the host layout calls a host route helper" do
    get janela.pane_path("orders", "revenue", "status")

    assert_response :success
    assert_select "caption", "Revenue by Status"
    assert_select "nav", count: 0
  end

  test "a frame request carries no layout at all" do
    get janela.pane_path("orders", "revenue", "status"), headers: { "Turbo-Frame" => "janela_orders_revenue_status_table" }

    assert_response :success
    assert_no_match "<html", response.body
    assert_select "caption", "Revenue by Status"
  end

  test "a null group is labelled and toggles the null predicate" do
    get janela.pane_path("orders", "revenue", "channel")

    assert_select "button[data-janela--frame-key-param=channel_null][data-janela--frame-value-param='1']", "(none)"
    assert_select "button[data-janela--frame-key-param=channel_eq][data-janela--frame-value-param=web]", "web"
  end

  test "a chart carries the filter each label toggles" do
    get janela.pane_path("orders", "revenue", "channel", as: "bar")

    assert_select "canvas[data-janela--chart-filters-value*=?]", "channel_null"
    assert_select "canvas[data-janela--chart-filters-value*=?]", "channel_eq"
  end

  test "the null group reads as selected when the null predicate is on" do
    get janela.pane_path("orders", "revenue", "channel", q: { channel_null: "1" })

    assert_select "button[aria-pressed=true]", "(none)"
  end

  test "an aliased dimension is titled by its name and filtered by its column" do
    get janela.pane_path("orders", "revenue", "customer")

    assert_select "caption", "Revenue by Customer"
    assert_select "button[data-janela--frame-key-param=customer_name_eq]", "Acme"
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

    assert_select "canvas[data-janela--chart-type-value=line][data-janela--chart-filters-value='{}']"
    assert_select "canvas[data-janela--chart-labels-value=?]", %w[2026-09-01 2026-09-02 2026-09-03 2026-09-04].to_json
  end

  test "an unknown granularity is a 400" do
    get janela.pane_path("orders", "revenue", "placed_on", granularity: "fortnight")

    assert_response :bad_request
  end

  test "rows are ordered by the measure and a limit keeps the top ones" do
    get janela.pane_path("orders", "revenue", "status", limit: 2)

    assert_select "tbody tr", count: 2
    assert_select "tbody tr:first-child td:last-child", "300.0"
    assert_select "turbo-frame#janela_orders_revenue_status_table_top2"
  end

  test "an invalid limit is a 400" do
    get janela.pane_path("orders", "revenue", "status", limit: "lots")

    assert_response :bad_request
  end

  test "the frame id matches what the helper renders" do
    get janela.pane_path("orders", "revenue", "status", as: "bar")

    assert_select "turbo-frame#janela_orders_revenue_status_bar"
  end
end
