require "test_helper"

# ADR 062, #90. A time pane held one measure over one dimension, drawn one
# way on one axis, and nothing accumulated. Two things were believed that
# measuring did not bear out: that Groupdate hands back the same kind of key
# for every time column (a date column's buckets are Dates and a timestamp's
# are Times, so a union has to go through the instant), and that Groupdate's
# own zero filling covers a shared axis (it fills inside each series' range,
# so two series that do not overlap leave a hole between them). The fixtures:
# four orders placed on 1 to 4 September 2026, the two paid ones shipped on
# 2 and 10 September, the other two never shipped.
class SeriesTest < ActionDispatch::IntegrationTest
  SHIPPED = { measure: "orders", by: "shipped_on", cumulative: "1", title: "Shipped to date" }.freeze
  PER_DAY = { measure: "orders", as: "bar", axis: "right" }.freeze

  def query(**options)
    Janela::Query.new(definition: Order.janela, measure: :orders, dimension: :placed_on, renderer: "line", **options)
  end

  def headers
    css_select("table.janela-pane thead th").map { |cell| cell.text.strip }
  end

  def cells(row)
    css_select("table.janela-pane tbody tr:nth-of-type(#{row}) td").map { |cell| cell.text.strip }
  end

  test "cumulative is a running total across the buckets, summed after the read" do
    assert_equal [ 1, 1, 1, 1 ], query.result.values
    assert_equal [ 1, 2, 3, 4 ], query(cumulative: true).result.values
    assert_equal [ 100.0, 150.0, 350.0, 375.0 ], Janela::Query.new(definition: Order.janela, measure: :revenue, dimension: :placed_on, cumulative: true).result.values.map(&:to_f)
  end

  test "a running total on a category pane or a single value is refused with its reason" do
    error = assert_raises(Janela::BadRequest) { Janela::Query.new(definition: Order.janela, measure: :orders, dimension: :status, cumulative: true) }
    assert_match(/cumulative applies to a time dimension/, error.message)
    assert_raises(Janela::BadRequest) { Janela::Query.new(definition: Order.janela, measure: :orders, cumulative: true) }
  end

  # The shipped series has rows on the 2nd and the 10th; the placed series
  # ends on the 4th. One axis, the 1st to the 10th, and the days between the
  # 4th and the 10th are there with zero placed and nothing shipped.
  test "a series by another time dimension shares the pane's buckets, zero where it has no row" do
    read = query(cumulative: true, series: [ SHIPPED ])
    result = read.result

    assert_equal (1..10).map { |day| format("2026-09-%02d", day) }, result.keys
    assert_equal [ 1, 2, 3, 4, 4, 4, 4, 4, 4, 4 ], result.values
    assert_equal [ 0, 1, 1, 1, 1, 1, 1, 1, 1, 2 ], read.drawn_series.first.values.values
  end

  test "a series that is not cumulative is the measure per bucket, and a bar on the right axis is drawn there" do
    read = query(series: [ PER_DAY ], granularity: "week")

    assert_equal [ 4 ], read.result.values
    series = read.drawn_series.first
    assert_equal "bar", series.renderer
    assert_equal "right", series.axis
    assert_equal [ 4 ], series.values.values
  end

  test "a series is named by its measure, its dimension when not the pane's, and to date when it accumulates" do
    read = query(cumulative: true, series: [ { measure: "orders", by: "shipped_on" }, { measure: "revenue" }, SHIPPED ])

    assert_equal "Orders to date", read.series_label
    assert_equal "Orders by Shipped on", read.series_label(read.series[0])
    assert_equal "Revenue", read.series_label(read.series[1])
    assert_equal "Shipped to date", read.series_label(read.series[2])
    assert_equal "Orders to date by Placed on per day", read.title
  end

  test "both axes are titled only when a series is on the right" do
    assert_nil query(series: [ SHIPPED ]).axis_titles
    assert_equal({ left: "Orders to date, Shipped to date", right: "Orders" }, query(cumulative: true, series: [ SHIPPED, PER_DAY ]).axis_titles)
  end

  test "a series the model did not declare, or that is not over time, or a fourth, is refused" do
    [ [ { measure: "nope" } ], [ { measure: "orders", by: "status" } ], [ { measure: "orders", by: "nope" } ],
      [ { measure: "orders", as: "pie" } ], [ { measure: "orders", axis: "top" } ], [ { measure: "orders", colour: "red" } ],
      [ {} ], [ SHIPPED, SHIPPED ], [ PER_DAY ] * 4, "orders" ].each do |bad|
      assert_raises(Janela::BadRequest, bad.inspect) { query(series: bad) }
    end
    assert_raises(Janela::BadRequest) { Janela::Query.new(definition: Order.janela, measure: :orders, dimension: :status, series: [ PER_DAY ]) }
  end

  test "the pane URL carries it, each series led by its measure, and a 400 names nothing internal" do
    get janela.pane_path("orders", "orders", "placed_on", granularity: "week", cumulative: 1, series: [ SHIPPED, PER_DAY ])

    assert_response :success
    assert_equal [ "Placed on", "Orders to date", "Shipped to date", "Orders" ], headers
    assert_equal [ "2026-08-31", "4", "1", "4" ], cells(1)
    assert_equal [ "2026-09-07", "4", "2", "0" ], cells(2)

    get janela.pane_path("orders", "orders", "placed_on", series: [ { measure: "nope" } ])
    assert_response :bad_request
    assert_select "p.janela-error", "That request is not allowed on this pane."
  end

  test "a chart is handed the further series, the primary's name and the axis titles, and nothing more without them" do
    get janela.pane_path("orders", "orders", "placed_on", as: "line", granularity: "week", cumulative: 1, series: [ SHIPPED, PER_DAY ])

    canvas = css_select("canvas.janela-chart").first
    assert_equal "Orders to date", canvas["data-janela--chart-label-value"]
    series = JSON.parse(canvas["data-janela--chart-series-value"])
    assert_equal [ "Shipped to date", "Orders" ], series.map { |each| each["label"] }
    assert_equal [ [ 1.0, 2.0 ], [ 4.0, 0.0 ] ], series.map { |each| each["values"] }
    assert_equal [ [ "1", "2" ], [ "4", "0" ] ], series.map { |each| each["formatted"] }
    assert_equal({ "left" => "Orders to date, Shipped to date", "right" => "Orders" }, JSON.parse(canvas["data-janela--chart-axes-value"]))

    get janela.pane_path("orders", "orders", "placed_on", as: "line", granularity: "week")
    canvas = css_select("canvas.janela-chart").first
    assert_nil canvas["data-janela--chart-series-value"]
    assert_nil canvas["data-janela--chart-label-value"]
    assert_nil canvas["data-janela--chart-axes-value"]
  end

  test "a filter on another dimension narrows every series, and the pane's own range narrows none" do
    get janela.pane_path("orders", "orders", "placed_on", granularity: "week", series: [ SHIPPED ],
                         q: { customer_region_in: [ "EU" ], placed_on_gteq: "2026-09-03", placed_on_lt: "2026-09-04" })

    assert_equal [ "2026-08-31", "2", "0" ], cells(1)
    assert_equal [ "2026-09-07", "0", "1" ], cells(2)
  end

  test "a ring ignores the series and a snapshot sums a stored series on read" do
    get janela.pane_path("orders", "orders", "placed_on", as: "doughnut", series: [ SHIPPED ])
    assert_response :success
    assert_select "thead", count: 0

    snapshot = Janela::Snapshot.take(name: "September", owner: customers(:acme), taken_at: Time.utc(2026, 9, 15)) do |take|
      take.pane Order, :orders, by: :placed_on
    end
    get janela.snapshot_pane_path(snapshot, "orders", "orders", "placed_on", cumulative: 1)
    assert_equal [ "1", "2", "3", "4" ], css_select("table.janela-pane tbody td:nth-of-type(2)").map { |cell| cell.text.strip }
  end

  test "janela_pane puts both in the URL, leads each series with its measure, and a set cumulative joins the frame id" do
    get orders_path

    assert_select "turbo-frame#janela_orders_orders_placed_on_month_line_cumulative" do |frames|
      src = CGI.unescape(frames.first["data-janela-src"])
      assert_includes src, "cumulative=1"
      assert_includes src, "series[][measure]=orders&series[][by]=shipped_on&series[][cumulative]=true&series[][title]=Orders shipped to date"
      assert_includes src, "series[][measure]=orders&series[][as]=bar&series[][axis]=right&series[][title]=Orders per month"
    end
    assert_select "turbo-frame#janela_orders_revenue_placed_on_month_line"
  end

  test "a stored pane carries them from the row, so a refresh keeps them" do
    pane = janela_frames(:orders).panes.create!(model: "orders", measure: "orders", dimension: "placed_on", renderer: "line", granularity: "week",
                                                cumulative: true, series: [ SHIPPED, PER_DAY ])

    get janela.frame_pane_path(janela_frames(:orders), pane)

    canvas = css_select("canvas.janela-chart").first
    assert_equal 2, JSON.parse(canvas["data-janela--chart-series-value"]).size
    assert_equal "Orders to date", canvas["data-janela--chart-label-value"]
  end

  test "a row is refused on save for what a URL would be refused for, and a blank slot is no series" do
    frame = janela_frames(:orders)

    pane = frame.panes.build(model: "orders", measure: "orders", dimension: "status", renderer: "bar", cumulative: true)
    assert_not pane.valid?
    assert_match(/time dimension/, pane.errors[:cumulative].first)

    pane = frame.panes.build(model: "orders", measure: "orders", dimension: "placed_on", renderer: "line", series: [ { measure: "nope" } ])
    assert_not pane.valid?
    assert_match(/not a measure/, pane.errors[:series].first)

    pane = frame.panes.create!(model: "orders", measure: "orders", dimension: "placed_on", renderer: "line",
                               series: [ { "measure" => "", "by" => "", "as" => "" }, { measure: "orders", by: "", axis: "right", title: "" } ])
    assert_equal [ { "measure" => "orders", "axis" => "right" } ], pane.series

    pane.update!(series: [ { measure: "" } ])
    assert_nil pane.series
  end

  # A pane with no dimension yet is offered them too, as it is offered a
  # granularity: the dimension is chosen on the same form, and the server
  # refuses the pair that cannot go together.
  test "the pane form offers a running total and one blank series slot beyond those held, not on a category pane" do
    get janela.edit_frame_pane_path(janela_frames(:orders), janela_panes(:revenue_by_month))

    assert_select "input[type=checkbox][name='pane[cumulative]']"
    assert_select "select[name='pane[series][][measure]']", count: 1
    assert_select "select[name='pane[series][][by]'] option[value=shipped_on]"

    pane = janela_frames(:orders).panes.create!(model: "orders", measure: "orders", dimension: "placed_on", renderer: "line", series: [ SHIPPED ])
    get janela.edit_frame_pane_path(janela_frames(:orders), pane)
    assert_select "select[name='pane[series][][measure]']", count: 2
    assert_select "input[name='pane_series_0_title'], input#pane_series_0_title[value='Shipped to date']"

    get janela.edit_frame_pane_path(janela_frames(:orders), janela_panes(:revenue_by_region))
    assert_select "input[name='pane[cumulative]']", count: 0
    assert_select "select[name='pane[series][][measure]']", count: 0
  end

  test "the form saves the slots as series and drops the blank one" do
    pane = janela_panes(:revenue_by_month)

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: {
      pane: { cumulative: "1", series: [ { measure: "orders", by: "shipped_on", cumulative: "1", as: "", axis: "left", title: "" },
                                         { measure: "", by: "", as: "", axis: "left", title: "" } ] } }

    assert_response :redirect
    pane.reload
    assert pane.cumulative
    assert_equal [ { "measure" => "orders", "by" => "shipped_on", "cumulative" => "1", "axis" => "left" } ], pane.series
  end

  test "an agent can set both, and the series' keys are in the tool's schema" do
    tools = Janela::Tools.new(scope: ->(model) { model.all }, write: true)

    pane = tools.call("add_pane", frame_id: janela_frames(:orders).id, model: "orders", measure: "orders", dimension: "placed_on",
                                  renderer: "line", cumulative: true, series: [ SHIPPED ])

    assert_equal true, pane[:cumulative]
    assert_equal [ SHIPPED.stringify_keys ], pane[:series]
    add = Janela::Tools.all(write: true).find { |tool| tool.name == "add_pane" }
    assert_equal %w[measure by cumulative as axis title], add.input_schema[:properties][:series][:items][:properties].keys.map(&:to_s)
  end

  test "the doctor names the two columns when a stored-frames host skips the migration" do
    [ "cumulative", "series" ].each do |column|
      without_column Janela::Pane, column do
        finding = Janela::Doctor.new(Rails.root).check.find { |f| f.code == "unmigrated-columns" }

        assert_equal :error, finding&.severity, column
        assert_includes finding.summary, column
      end
    end
  end

  private
    # Borrowed from the doctor's own tests: the column gone from what the
    # model believes it has, without touching the database.
    def without_column(model, column)
      names = model.column_names - [ column ]
      model.singleton_class.define_method(:column_names) { names }
      yield
    ensure
      model.singleton_class.remove_method(:column_names)
    end
end
