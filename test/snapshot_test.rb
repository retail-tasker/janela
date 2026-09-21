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

  # ADR 025 believed a snapshot taken under a predicate later disallowed
  # "would raise when read", and left the choice open for whoever built it.
  # False: stored_result looks a pane up by key and returns the stored JSON,
  # never re-running the query or re-validating the filters it was taken
  # under. A snapshot's own `filters` are metadata for `Snapshot.take` to
  # build its panes with; nothing at read time touches Ransack again.
  test "a snapshot taken under a filter no longer allowed still reads, because reading never re-filters" do
    snapshot = Janela::Snapshot.create!(name: "s", taken_at: Time.current, filters: { "status_cont" => "pai" },
      panes: [ { "model" => "orders", "measure" => "revenue", "dimension" => nil, "granularity" => nil,
                 "limit" => nil, "result" => 300.0 } ])

    assert_equal 300.0, stored(snapshot, Order, :revenue)
  end

  test "the job takes a snapshot from serialisable arguments" do
    Janela::SnapshotJob.perform_now(name: "from job", filters: { "customer_region_eq" => "EU" },
      panes: [ { "model" => "orders", "measure" => "revenue" }, { "model" => "orders", "measure" => "orders", "by" => "status", "limit" => 2 } ])

    snapshot = Janela::Snapshot.find_by!(name: "from job")
    assert_equal 225.0, stored(snapshot, Order, :revenue)
    assert_equal({ "paid" => 1, "pending" => 1 }, stored(snapshot, Order, :orders, by: :status, limit: 2))
  end

  # ADR 033. A snapshot is never created in a request, so the owner is an
  # argument rather than the controller hook a frame gets (ADR 019): a hook
  # reaching for the current tenant would work in a console and return nil in
  # the job, which is the silent failure that pattern exists to avoid.
  test "a snapshot is assigned the owner it was taken for" do
    acme = customers(:acme)

    snapshot = Janela::Snapshot.take(name: "September", owner: acme) { |take| take.pane Order, :revenue }

    assert_equal acme, snapshot.owner
  end

  test "a snapshot taken without an owner has none, which is the narrow default" do
    snapshot = Janela::Snapshot.take(name: "September") { |take| take.pane Order, :revenue }

    assert_nil snapshot.owner
  end

  # The whole point of the column: a host's policy has something to filter on,
  # which it did not before and which the guide called the rough edge.
  test "a host's scope can filter snapshots by owner" do
    acme = customers(:acme)
    Janela::Snapshot.take(name: "Acme", owner: acme) { |take| take.pane Order, :revenue }
    Janela::Snapshot.take(name: "Globex", owner: customers(:globex)) { |take| take.pane Order, :revenue }

    assert_equal %w[Acme], Janela::Snapshot.where(owner: acme).pluck(:name)
  end

  # ActiveJob cannot serialise a relation, which is why on: is not a job
  # argument, but it serialises a record through its GlobalID.
  test "the job carries an owner across the queue" do
    acme = customers(:acme)

    Janela::SnapshotJob.perform_now(name: "Scheduled", owner: acme,
      panes: [ { "model" => "orders", "measure" => "revenue" } ])

    assert_equal acme, Janela::Snapshot.find_by(name: "Scheduled").owner
  end

  private
    def stored(snapshot, model, measure, **options)
      Janela::Query.new(definition: model.janela, measure: measure, dimension: options[:by],
                       granularity: options[:granularity], limit: options[:limit], snapshot: snapshot).result
    end
end
