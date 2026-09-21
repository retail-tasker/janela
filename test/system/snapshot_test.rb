require "application_system_test_case"

class SnapshotSystemTest < ApplicationSystemTestCase
  test "a published snapshot shows frozen numbers and offers nothing to click" do
    # Owned, because the demo filters snapshots by owner since ADR 033 and one
    # taken without an owner is invisible to that policy.
    snapshot = Janela::Snapshot.take(name: "Before the refund", owner: customers(:acme),
                                     filters: { status_in: %w[paid pending] }) do |take|
      take.pane Order, :revenue
      take.pane Order, :orders
      take.pane Order, :revenue, by: :status
      take.pane Order, :revenue, by: :region
      take.pane Order, :revenue, by: :customer, limit: 5
      take.pane Order, :revenue, by: :placed_on, granularity: :month
    end
    Order.find_by!(status: "paid", amount: 200).update!(amount: 999)

    visit snapshot_path(snapshot)

    assert_text "Before the refund"
    within(:xpath, "//p[contains(@class, 'janela-value')][span[starts-with(text(), 'Revenue')]]") { assert_text "$325.00" }
    within(:xpath, "//table[caption[starts-with(text(), 'Revenue by Region')]]") do
      assert_text "$225.00"
      assert_no_selector "button"
    end
    assert_no_selector "[data-controller~='janela--frame']"
    assert_selector "canvas.janela-chart", minimum: 2
  end
end
