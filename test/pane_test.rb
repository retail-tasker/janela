require "test_helper"

class PaneTest < ActiveSupport::TestCase
  setup { @frame = Janela::Frame.create!(name: "Orders") }

  test "a new pane goes after the panes already in the frame" do
    first = @frame.panes.create!(model: "orders", measure: "revenue")
    second = @frame.panes.create!(model: "orders", measure: "orders")

    assert_equal [ 1, 2 ], [ first.position, second.position ]
    assert_equal 7, @frame.panes.create!(model: "orders", measure: "revenue", position: 7).position
  end

  test "a span stays inside the scale the stylesheet enumerates" do
    assert pane(span: 12).valid?
    assert_not pane(span: 13).valid?
    assert_not pane(span: 0).valid?
  end

  test "a limit is a whole number of rows Janela will draw" do
    assert pane(dimension: "status", limit: 1000).valid?
    assert pane(dimension: "status", limit: nil).valid?
    assert_not pane(dimension: "status", limit: 1001).valid?
    assert_not pane(dimension: "status", limit: 0).valid?
  end

  test "a row may only name a model with a janela block" do
    row = pane(model: "customers")

    assert_not row.valid?
    assert_equal [ "\"customers\" is not a janela model" ], row.errors[:model]
    assert_not pane(model: "").valid?
  end

  test "a row may only name a measure the model declares" do
    row = pane(measure: "profit")

    assert_not row.valid?
    assert_equal [ "\"profit\" is not a measure of Order" ], row.errors[:measure]
    assert_not pane(measure: nil).valid?
  end

  test "a row may only name a dimension the model declares" do
    row = pane(dimension: "colour")

    assert_not row.valid?
    assert_equal [ "\"colour\" is not a dimension of Order" ], row.errors[:dimension]
  end

  test "a row may only name a renderer Janela can draw" do
    row = pane(dimension: "status", renderer: "pie")

    assert_not row.valid?
    assert_equal [ "must be one of table, bar, line" ], row.errors[:renderer]
  end

  test "a granularity must be one Groupdate buckets, on a time dimension" do
    assert pane(dimension: "placed_on", granularity: "week").valid?

    row = pane(dimension: "placed_on", granularity: "fortnight")
    assert_not row.valid?
    assert_equal [ "must be one of hour, day, week, month, quarter, year" ], row.errors[:granularity]

    row = pane(dimension: "status", granularity: "week")
    assert_not row.valid?
    assert_equal [ "only applies to a time dimension, and status is not one" ], row.errors[:granularity]
  end

  test "a bad row is rejected rather than raising" do
    assert_nothing_raised do
      assert_not pane(model: "nothing", measure: "nothing", dimension: "nothing", renderer: "nothing").valid?
    end
  end

  test "a row's turbo frame id is the row, so two alike rows do not collide" do
    one = @frame.panes.create!(model: "orders", measure: "revenue", dimension: "status")
    two = @frame.panes.create!(model: "orders", measure: "revenue", dimension: "status")

    assert_equal "janela_pane_#{one.id}", one.turbo_frame_id
    assert_not_equal one.turbo_frame_id, two.turbo_frame_id
  end

  test "a row builds the query it shows, under the filters it is rendered with" do
    row = @frame.panes.create!(model: "orders", measure: "revenue", dimension: "status",
                               renderer: "bar", limit: 1, title: "Money by status")
    query = row.query(filters: { "customer_region_eq" => "APAC" })

    assert_equal Order, query.model
    assert_equal :revenue, query.measure
    assert_equal :status, query.dimension
    assert_equal "bar", query.renderer
    assert_equal 1, query.limit
    assert_equal "Money by status", query.title
    assert_equal({ "paid" => 100.0 }, query.result.transform_values(&:to_f))
  end

  test "a row with no title of its own is described by its query" do
    row = @frame.panes.create!(model: "orders", measure: "revenue", dimension: "placed_on", granularity: "month")

    assert_equal "Revenue by Placed on per month", row.query.title
  end

  private
    def pane(**attributes)
      @frame.panes.build({ model: "orders", measure: "revenue" }.merge(attributes))
    end
end
