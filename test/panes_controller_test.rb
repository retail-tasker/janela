require "test_helper"

class PanesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @frame = janela_frames(:orders)
    @pane = janela_panes(:revenue_by_region)
  end

  test "a pane row renders its own title and data" do
    get janela.frame_pane_path(@frame, @pane)

    assert_response :success
    assert_select "table.janela-pane caption", "Where the money is"
    assert_select "td", "APAC"
    assert_select "td", "150.0"
  end

  test "a pane row is addressed as a row, so alike rows do not share a turbo frame" do
    twin = @frame.panes.create!(model: "orders", measure: "revenue", dimension: "region")

    get janela.frame_pane_path(@frame, @pane)
    assert_select "turbo-frame##{@pane.turbo_frame_id}"

    get janela.frame_pane_path(@frame, twin)
    assert_select "turbo-frame##{twin.turbo_frame_id}"
  end

  test "a pane row applies the filters it is asked for" do
    get janela.frame_pane_path(@frame, janela_panes(:revenue_total), q: { status_eq: "paid" })

    assert_response :success
    assert_select ".janela-value-number", "300.0"
  end

  test "a pane row ignores a filter on its own dimension but marks it pressed" do
    get janela.frame_pane_path(@frame, @pane, q: { customer_region_eq: "APAC" })

    assert_response :success
    assert_select "td", "EU"
    assert_select "button[aria-pressed=true]", "APAC"
  end

  test "a pane row of a frame that is not there is a 404 in the frame" do
    get janela.frame_pane_path(@frame.id + 999, @pane), headers: { "Turbo-Frame" => @pane.turbo_frame_id }

    assert_response :not_found
    assert_select "turbo-frame##{@pane.turbo_frame_id} p.janela-error", "There is no such pane."
  end

  test "a pane row belonging to another frame is not reachable through this one" do
    other = janela_frames(:empty).panes.create!(model: "orders", measure: "orders")

    get janela.frame_pane_path(@frame, other)

    assert_response :not_found
  end

  test "the pane grammar still answers under the same mount" do
    get janela.pane_path("orders", "revenue", "status")

    assert_response :success
    assert_select "caption", "Revenue by Status"
  end
end
