require "test_helper"

# #63: a frame had no data-side home for a filter that is permanent rather
# than per-record, so the same condition had to be typed into every view
# that rendered it. Fixtures: $375 in all, $300 paid, $50 refunded, $25
# pending; APAC's share of paid and pending is Acme's $100 paid (ADR 043).
class FrameDefaultFilterTest < ActiveSupport::TestCase
  test "a frame's default filter is what a pane over the model it names receives" do
    frame = janela_frames(:orders)
    frame.update!(default_model: "orders", default_where: { status_in: %w[paid pending] })

    assert_equal({ "status_in" => %w[paid pending] }, frame.default_for(Order))
  end

  test "a frame with no default filter narrows nothing" do
    frame = janela_frames(:orders)

    assert_equal({}, frame.default_for(Order))
  end

  test "a frame's default filter does not reach a pane over a different model" do
    frame = janela_frames(:orders)
    frame.update!(default_model: "orders", default_where: { status_in: %w[paid pending] })

    assert_equal({}, frame.default_for(Customer))
  end

  test "default_model and default_where must be set together" do
    frame = janela_frames(:orders)

    frame.default_model = "orders"
    assert_not frame.valid?
    assert_includes frame.errors[:default_model], "cannot be set without default_where"

    frame.default_model = nil
    frame.default_where = { status_eq: "paid" }
    assert_not frame.valid?
    assert_includes frame.errors[:default_where], "cannot be set without default_model"
  end

  test "default_model must be a janela model" do
    frame = janela_frames(:orders)
    frame.default_model = "customers"
    frame.default_where = { region_eq: "APAC" }

    assert_not frame.valid?
    assert_includes frame.errors[:default_model], "must be a model with a janela block"
  end

  test "default_where is bounded like any other filter, at save time rather than only at render" do
    frame = janela_frames(:orders)
    frame.default_model = "orders"
    frame.default_where = { amount_gt: "0" }

    assert_not frame.valid?
    assert_includes frame.errors[:default_where].join, "does not allow filtering on amount_gt"
  end

  test "a stored pane's query composes the frame's default ahead of a fixed filter" do
    frame = janela_frames(:orders)
    frame.update!(default_model: "orders", default_where: { status_in: %w[paid pending] })
    pane = frame.panes.create!(model: "orders", measure: "revenue")

    query = pane.query(fixed: { "customer_region_eq" => "APAC" })
    result = query.result(on: Order.all)

    assert_equal 100.0, result
  end

  # #64, ADR 044: "this queue never counts a refunded order" is the sentence
  # this column exists for, and it can now be said as an exclusion rather
  # than as an _in list that stops covering the dashboard the day a new
  # status value is added.
  test "a frame's default filter can exclude a value instead of naming every other one" do
    frame = janela_frames(:orders)
    frame.update!(default_model: "orders", default_where: { status_not_eq: "refunded" })
    pane = frame.panes.create!(model: "orders", measure: "revenue")

    query = pane.query
    result = query.result(on: Order.all)

    assert_equal 325.0, result
  end
end
