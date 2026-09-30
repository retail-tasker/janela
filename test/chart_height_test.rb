require "test_helper"

# ADR 047, #24. Believed: a chart is enormous and a host cannot cap it from
# outside. Measured: the 20rem cap already holds it at 320px and a host's
# max-height works, so what a host cannot do is set a height, or make a chart
# taller than 2:1 of its width, and a stored frame has no height at all.
class ChartHeightTest < ActionDispatch::IntegrationTest
  test "with no height a chart is exactly what it was: no box, the canvas straight in the figure" do
    get janela.pane_path("orders", "revenue", "status", as: "bar")

    assert_select "figure.janela-pane > canvas.janela-chart"
    assert_select ".janela-chart-box", count: 0
    assert_select "canvas[data-janela--chart-fixed-height-value]", count: 0
  end

  test "a height puts the canvas in a box of that step, and tells the chart controller" do
    get janela.pane_path("orders", "revenue", "status", as: "bar", height: 2)

    assert_select "figure.janela-pane > figcaption.janela-chart-title", "Revenue by Status"
    assert_select "figure.janela-pane > div.janela-chart-box.janela-h-2 > canvas.janela-chart[data-janela--chart-fixed-height-value=true]"
    title_id = css_select("figcaption").first["id"]
    assert_select "canvas[aria-labelledby=?]", title_id
  end

  test "every step from 1 to 5 is a class the stylesheet defines" do
    css = File.read(Janela::Engine.root.join("app/assets/stylesheets/janela.css"))

    (1..5).each do |step|
      get janela.pane_path("orders", "revenue", "status", as: "bar", height: step)
      assert_select "div.janela-chart-box.janela-h-#{step}"
      assert_match(/\.janela-h-#{step}\s*\{/, css)
    end
  end

  test "a line takes a height the same way" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line", height: 3)

    assert_select "div.janela-chart-box.janela-h-3 > canvas[data-janela--chart-type-value=line]"
  end

  # A pane switched from a bar to a ring and back keeps its height, so a
  # height on a renderer that has no canvas is ignored, not an error.
  test "a ring, a table and a single value ignore a height" do
    get janela.pane_path("orders", "revenue", "status", as: "doughnut", height: 2)
    assert_response :success
    assert_select ".janela-chart-box", count: 0

    get janela.pane_path("orders", "revenue", "status", height: 2)
    assert_response :success
    assert_select ".janela-chart-box", count: 0

    get janela.pane_path("orders", "revenue", height: 2)
    assert_response :success
    assert_select ".janela-value-number", "$375.00"
  end

  test "a height that is not a step is a 400 that names nothing internal" do
    [ "0", "6", "tall", "2.5", "-1" ].each do |bad|
      get janela.pane_path("orders", "revenue", "status", as: "bar", height: bad)

      assert_response :bad_request, bad
      assert_select "p.janela-error", "That request is not allowed on this pane."
    end
  end

  test "a snapshot pane takes a height too" do
    snapshot = Janela::Snapshot.take(name: "September", owner: customers(:acme), taken_at: Time.utc(2026, 9, 15)) do |take|
      take.pane Order, :revenue, by: :status
    end

    get janela.snapshot_pane_path(snapshot, "orders", "revenue", "status", as: "bar", height: 4)

    assert_select "div.janela-chart-box.janela-h-4 > canvas"
  end

  test "a stored pane carries its height from the row, so a refresh keeps it" do
    pane = janela_frames(:orders).panes.create!(model: "orders", measure: "revenue", dimension: "status", renderer: "bar", height: 2)

    get janela.frame_pane_path(janela_frames(:orders), pane)

    assert_select "div.janela-chart-box.janela-h-2 > canvas"
  end

  test "a stored pane's height is one of the five steps, or nothing" do
    frame = janela_frames(:orders)
    pane = ->(height) { frame.panes.new(model: "orders", measure: "revenue", dimension: "status", renderer: "bar", height: height) }

    assert_predicate pane.(nil), :valid?
    (1..5).each { |step| assert_predicate pane.(step), :valid?, step }
    [ 0, 6, -1 ].each { |bad| assert_not_predicate pane.(bad), :valid?, bad }
    assert_equal Janela::Pane::HEIGHTS.to_a, (1..5).to_a
  end

  test "the pane form offers a height, with Automatic first" do
    get janela.edit_frame_pane_path(janela_frames(:orders), janela_panes(:revenue_by_status_bar))

    assert_select "select[name='pane[height]'] option", count: 6
    assert_select "select[name='pane[height]'] option:first-child", text: "Automatic"
  end

  test "the form saves a height, and blank clears it" do
    pane = janela_panes(:revenue_by_status_bar)

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { height: "3" } }
    assert_equal 3, pane.reload.height

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { height: "" } }
    assert_nil pane.reload.height
  end
end

# The helper is the other half of one vocabulary. The height rides in the pane's
# URL, since the pane's content is rendered from it again on every cross-filter,
# and stays out of the frame's id: a height is how a pane is drawn, not which
# query it is (ADR 029).
class ChartHeightHelperTest < ActionDispatch::IntegrationTest
  test "janela_pane puts the height in its URL and leaves the frame id alone" do
    get orders_path

    assert_select "turbo-frame#janela_orders_revenue_placed_on_month_line[data-janela-src*='height=3']"
    assert_select "turbo-frame[data-janela-src*='height=']", count: 1
  end
end
