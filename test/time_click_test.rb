require "test_helper"

# ADR 045: clicking a time bucket filters the frame to the range it covers.
# ADR 006 left time panes as plain text because a click wrote one condition
# and a bucket needs two.
class TimeClickTest < ActionDispatch::IntegrationTest
  test "a day bucket is the range from its start to the next day's start" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line")

    filters = JSON.parse(css_select("canvas").first["data-janela--chart-filters-value"])
    assert_equal({ "placed_on_gteq" => "2026-09-01", "placed_on_lt" => "2026-09-02" }, filters["2026-09-01"])
  end

  # Believed while writing this: a label could be read back into a range.
  # "Sep 2026" and "Q3 2026" cannot, so the range comes from the bucket.
  test "a month, a quarter and a year bucket each cover their whole span" do
    { "month" => [ "Sep 2026", "2026-09-01", "2026-10-01" ],
      "quarter" => [ "Q3 2026", "2026-07-01", "2026-10-01" ],
      "year" => [ "2026", "2026-01-01", "2027-01-01" ] }.each do |granularity, (label, from, to)|
      get janela.pane_path("orders", "revenue", "placed_on", as: "line", granularity: granularity)

      filters = JSON.parse(css_select("canvas").first["data-janela--chart-filters-value"])
      assert_equal({ "placed_on_gteq" => from, "placed_on_lt" => to }, filters[label], granularity)
    end
  end

  test "a week bucket starts on the host's first day of the week" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line", granularity: "week")

    filters = JSON.parse(css_select("canvas").first["data-janela--chart-filters-value"])
    assert_equal({ "placed_on_gteq" => "2026-08-31", "placed_on_lt" => "2026-09-07" }, filters["2026-08-31"])
  end

  test "a time table's labels are buttons carrying the range" do
    get janela.pane_path("orders", "revenue", "placed_on", granularity: "month")

    button = css_select("table.janela-pane button").first
    assert_equal "Sep 2026", button.text.strip
    assert_equal({ "placed_on_gteq" => "2026-09-01", "placed_on_lt" => "2026-10-01" },
                 JSON.parse(button["data-janela--frame-filters-param"]))
    assert_nil button["data-janela--frame-key-param"]
  end

  # Believed: a range filter on the dimension would simply narrow the pane, as
  # ADR 006 lets a host do. Measured: it left one point on the line, the pane
  # that was clicked collapsing to the bucket it was clicked on.
  test "a time pane keeps its whole series under the reader's range and marks the buckets inside it" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line", q: { placed_on_gteq: "2026-09-02", placed_on_lt: "2026-09-04" })

    canvas = css_select("canvas").first
    assert_equal [ "2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04" ], JSON.parse(canvas["data-janela--chart-labels-value"])
    assert_equal [ "2026-09-02", "2026-09-03" ], JSON.parse(canvas["data-janela--chart-selected-value"])
  end

  test "clicking a month selects every day of it on a day pane" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line", q: { placed_on_gteq: "2026-09-01", placed_on_lt: "2026-10-01" })

    assert_equal 4, JSON.parse(css_select("canvas").first["data-janela--chart-selected-value"]).size
  end

  test "a table row is pressed when its bucket is inside the range" do
    get janela.pane_path("orders", "revenue", "placed_on", granularity: "day", q: { placed_on_gteq: "2026-09-02", placed_on_lt: "2026-09-03" })

    assert_select "button[aria-pressed=true]", "2026-09-02"
    assert_select "button[aria-pressed=false]", count: 3
  end

  test "a range elsewhere re-scopes the other panes" do
    get janela.pane_path("orders", "revenue", "status", q: { placed_on_gteq: "2026-09-01", placed_on_lt: "2026-09-02" })

    assert_select "td", "$100.00"
    assert_select "td", text: "$300.00", count: 0
  end

  test "the single total applies the range" do
    get janela.pane_path("orders", "revenue", q: { placed_on_gteq: "2026-09-03", placed_on_lt: "2026-09-04" })

    assert_select ".janela-value-number", "$200.00"
  end

  # ADR 040: what a host fixes narrows a pane on its own dimension, and what
  # the reader selects does not. The supported way to fix a range is unchanged.
  test "a range the host fixes still narrows the time pane itself" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line", where: { placed_on_gteq: "2026-09-03", placed_on_lt: "2026-09-05" })

    assert_equal [ "2026-09-03", "2026-09-04" ], JSON.parse(css_select("canvas").first["data-janela--chart-labels-value"])
  end

  test "a range needs both ends to be a selection" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line", q: { placed_on_gteq: "2026-09-02" })

    assert_equal [], JSON.parse(css_select("canvas").first["data-janela--chart-selected-value"])
  end

  test "a time pane says a second bucket cannot be added" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line")

    assert_select "canvas[aria-description*='Ctrl']"

    get janela.pane_path("orders", "revenue", "placed_on")
    assert_select "table.janela-pane[aria-description*='Ctrl']"
  end

  test "a stored snapshot is still not clickable" do
    query = Janela::Query.new(definition: Order.janela, measure: :revenue, dimension: :placed_on,
                              snapshot: Struct.new(:id, :taken_at).new(1, Time.current))

    assert_not_predicate query, :clickable?
  end

  # The case ADR 045 left unmeasured. The dummy declares no dimension on a
  # timestamp column, so this builds one. Bucketed and filtered in Brisbane the
  # range picks out the same rows the bucket holds, which is the whole claim.
  test "a timestamp bucket's range is written in the zone it was bucketed in" do
    dimension = Janela::Dimension.new(:placed_at, model: Order, column: :created_at, granularity: :day)
    Order.update_all(created_at: Time.utc(2026, 9, 1, 14, 30)) # 00:30 on the 2nd in Brisbane

    Time.use_zone("Australia/Brisbane") do
      definition = Order.janela
      definition.dimensions[:placed_at] = dimension
      series = definition.series(:orders, by: :placed_at)
      from, to = dimension.bounds(series.keys.first, "day")

      assert_equal [ "2026-09-02T00:00:00+10:00", "2026-09-03T00:00:00+10:00" ], [ from, to ]
      assert_equal 4, definition.query(:orders, where: { "created_at_gteq" => from, "created_at_lt" => to })
      assert_equal 0, definition.query(:orders, where: { "created_at_gteq" => "2026-09-01T00:00:00+10:00", "created_at_lt" => from })
    end
  ensure
    Order.janela.dimensions.delete(:placed_at)
  end

  test "a date column's range is written as dates" do
    dimension = Order.janela.dimension!(:placed_on)

    assert_equal [ "2026-09-01", "2026-09-02" ], dimension.bounds(Date.new(2026, 9, 1), "day")
    assert_equal [ "2026-09-01", "2026-10-01" ], dimension.bounds(Date.new(2026, 9, 1), "month")
  end
end
