require "test_helper"

class SnapshotPanesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @snapshot = Janela::Snapshot.take(name: "September", filters: { customer_region_eq: "APAC" }, taken_at: Time.utc(2026, 9, 15)) do |take|
      take.pane Order, :revenue
      take.pane Order, :revenue, by: :status
    end
  end

  test "a stored pane renders its frozen values with nothing to click" do
    get janela.snapshot_pane_path(@snapshot, "orders", "revenue", "status")

    assert_response :success
    assert_select "caption", "Revenue by Status as of 15 Sep 2026"
    assert_select "td span", "paid"
    assert_select "td", "100.0"
    assert_select "button", count: 0
    assert_select "turbo-frame#janela_snapshot_#{@snapshot.id}_orders_revenue_status_table"
  end

  test "request filters are ignored because the snapshot's were fixed when taken" do
    get janela.snapshot_pane_path(@snapshot, "orders", "revenue", "status", q: { customer_region_eq: "EU" })

    assert_select "td", "100.0"
    assert_select "td", text: "200.0", count: 0
  end

  test "a stored single value renders as of its date" do
    get janela.snapshot_pane_path(@snapshot, "orders", "revenue")

    assert_select ".janela-value-label", "Revenue as of 15 Sep 2026"
    assert_select ".janela-value-number", "150.0"
  end

  test "a stored pane can be drawn as a chart that does not toggle anything" do
    get janela.snapshot_pane_path(@snapshot, "orders", "revenue", "status", as: "bar")

    assert_select "canvas[data-janela--chart-filters-value='{}']"
  end

  test "a pane the snapshot did not freeze is a 404" do
    get janela.snapshot_pane_path(@snapshot, "orders", "orders", "region")

    assert_response :not_found
    assert_select "p.janela-error", "There is no such pane."
  end

  test "an unknown snapshot is a 404" do
    get janela.snapshot_pane_path(0, "orders", "revenue")

    assert_response :not_found
  end
end
