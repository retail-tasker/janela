require "test_helper"

# A frame rendered by a host's own page, which is the whole of build 2: the
# host owns the page and Janela renders the rows into it (ADR 012, ADR 014).
class FramesTest < ActionDispatch::IntegrationTest
  test "a frame renders its panes inline, so the page is correct before any JavaScript" do
    get frame_path(janela_frames(:orders))

    assert_response :success
    assert_select ".janela-value .janela-value-number", "$375.00"
    assert_select "table.janela-pane caption", "Where the money is"
    assert_select "turbo-frame##{janela_panes(:revenue_total).turbo_frame_id} .janela-value"
  end

  test "an inline pane carries no src, which would throw its content away" do
    get frame_path(janela_frames(:orders))

    assert_select "turbo-frame[data-janela--frame-target=pane]", 4
    assert_select "turbo-frame[src]", false
    assert_select "turbo-frame[data-janela-src=?]", "/dashboards/#{janela_frames(:orders).id}/panes/#{janela_panes(:revenue_total).id}"
  end

  test "the grid classes are the numbers on the records" do
    frame = janela_frames(:orders)

    get frame_path(frame)

    assert_select "div.janela-frame.janela-cols-3.janela-gap-4"
    assert_select "turbo-frame##{janela_panes(:revenue_by_status_bar).turbo_frame_id}.janela-span-2"
    assert_select "turbo-frame##{janela_panes(:revenue_by_month).turbo_frame_id}.janela-span-3"
  end

  test "the page URL's filters reach every pane of a frame" do
    get frame_path(janela_frames(:orders), q: { status_eq: "paid" })

    assert_response :success
    assert_select ".janela-value .janela-value-number", "$300.00"
    assert_select "[data-janela--frame-filters-value=?]", { "status_eq" => "paid" }.to_json
  end

  test "a frame with no panes renders an empty grid rather than failing" do
    get frame_path(janela_frames(:empty))

    assert_response :success
    assert_select "div.janela-frame.janela-cols-2.janela-gap-0"
    assert_select "turbo-frame", false
  end

  test "the hand written form still works alongside the record form" do
    get root_path

    assert_response :success
    assert_select "[data-controller=janela--frame]"
    assert_select "turbo-frame[src*=?]", "/dashboards/orders/revenue"
  end

  test "the engine's own frame page renders a chart pane as a table, since it loads no chart runtime" do
    frame = Janela::Frame.create!(name: "Charts", columns: 1, gap: 0, owner: customers(:acme))
    frame.panes.create!(model: "orders", measure: "revenue", dimension: "status", renderer: "bar")

    get janela.frame_path(frame)

    assert_response :success
    assert_select "canvas.janela-chart", count: 0
    assert_select "table.janela-pane caption", "Revenue by Status"
  end

  test "a host's own page still renders the chart the row asked for" do
    frame = Janela::Frame.create!(name: "Charts", columns: 1, gap: 0, owner: customers(:acme))
    frame.panes.create!(model: "orders", measure: "revenue", dimension: "status", renderer: "bar")

    get frame_path(frame)

    assert_response :success
    assert_select "canvas.janela-chart[data-janela--chart-type-value=bar]"
  end
end
