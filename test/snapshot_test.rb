require "test_helper"

class SnapshotTest < ActiveSupport::TestCase
  test "taking a snapshot freezes several panes at one instant under one set of filters" do
    snapshot = Janela::Snapshot.take(name: "September", filters: { status_eq: "paid" }) do |take|
      take.pane Order, :revenue
      take.pane Order, :revenue, by: :status
      take.pane Order, :revenue, by: :region
    end

    assert_equal "September", snapshot.name
    assert_equal({ "status_eq" => "paid" }, snapshot.filters)
    assert_equal 3, snapshot.panes.size
    assert_equal 300.0, stored(snapshot, Order, :revenue)
    assert_equal({ "paid" => 300.0, "refunded" => 50.0, "pending" => 25.0 }, stored(snapshot, Order, :revenue, by: :status))
    assert_equal({ "EU" => 200.0, "APAC" => 100.0 }, stored(snapshot, Order, :revenue, by: :region))
  end

  test "a pane's own dimension ignores the snapshot filters, as on a live dashboard" do
    snapshot = Janela::Snapshot.take(name: "s", filters: { status_eq: "paid" }) { |take| take.pane Order, :revenue, by: :status }

    assert_equal 3, stored(snapshot, Order, :revenue, by: :status).size
  end

  test "each pane can be scoped separately" do
    snapshot = Janela::Snapshot.take(name: "APAC only") do |take|
      take.pane Order, :revenue, on: Order.joins(:customer).where(customers: { region: "APAC" })
      take.pane Order, :orders
    end

    assert_equal 150.0, stored(snapshot, Order, :revenue)
    assert_equal 4, stored(snapshot, Order, :orders)
  end

  test "time panes store their effective granularity and can be found without restating it" do
    snapshot = Janela::Snapshot.take(name: "s") { |take| take.pane Order, :revenue, by: :placed_on }

    assert_equal "day", snapshot.panes.first["granularity"]
    assert_equal 4, stored(snapshot, Order, :revenue, by: :placed_on).size
    assert_equal 4, stored(snapshot, Order, :revenue, by: :placed_on, granularity: :day).size
  end

  test "results are stored as JSON numbers, not decimal strings" do
    snapshot = Janela::Snapshot.take(name: "s") { |take| take.pane Order, :revenue }

    assert_kind_of Float, Janela::Snapshot.find(snapshot.id).panes.first["result"]
  end

  test "asking a snapshot for a pane it did not freeze raises" do
    snapshot = Janela::Snapshot.take(name: "s") { |take| take.pane Order, :revenue }

    assert_raises(Janela::Error) { stored(snapshot, Order, :orders) }
    assert_raises(Janela::Error) { stored(snapshot, Order, :revenue, by: :status) }
  end

  test "the job takes a snapshot from serialisable arguments" do
    Janela::SnapshotJob.perform_now(name: "from job", filters: { "customer_region_eq" => "EU" },
      panes: [ { "model" => "orders", "measure" => "revenue" }, { "model" => "orders", "measure" => "orders", "by" => "status", "limit" => 2 } ])

    snapshot = Janela::Snapshot.find_by!(name: "from job")
    assert_equal 225.0, stored(snapshot, Order, :revenue)
    assert_equal({ "paid" => 1, "pending" => 1 }, stored(snapshot, Order, :orders, by: :status, limit: 2))
  end

  private
    def stored(snapshot, model, measure, **options)
      Janela::Pane.new(definition: model.janela, measure: measure, dimension: options[:by],
                       granularity: options[:granularity], limit: options[:limit], snapshot: snapshot).result
    end
end
