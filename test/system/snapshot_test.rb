require "application_system_test_case"

class SnapshotSystemTest < ApplicationSystemTestCase
  test "a published snapshot shows frozen numbers and offers nothing to click" do
    snapshot = Janela::Snapshot.take(name: "Before the refund", filters: { status_in: %w[paid pending] }) do |take|
      take.pane Order, :revenue
      take.pane Order, :revenue, by: :status
    end
    Order.find_by!(status: "paid", amount: 200).update!(amount: 999)

    visit snapshot_path(snapshot)

    assert_text "Before the refund"
    within(".janela-value") { assert_text "325.0" }
    within(:xpath, "//table") do
      assert_text "300.0"
      assert_no_selector "button"
    end
    assert_no_selector "[data-controller~='janela--dashboard']"
    assert_selector "canvas.janela-chart"
  end
end
