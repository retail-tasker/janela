require "test_helper"

# The shape docs/multi-tenancy.md teaches a host whose tenancy lives in its
# policies: the job's one question answered in Ruby, where a relation is still
# a relation, rather than in a symbol that cannot carry one (ADR 034).
class ScopedSnapshotJob < Janela::SnapshotJob
  private def scope_for(model) = model.where(customer: owner)
end

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
    Janela::SnapshotJob.perform_now(name: "from job", scope: :model_default, filters: { "customer_region_eq" => "EU" },
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

    Janela::SnapshotJob.perform_now(name: "Scheduled", owner: acme, scope: :model_default,
      panes: [ { "model" => "orders", "measure" => "revenue" } ])

    assert_equal acme, Janela::Snapshot.find_by(name: "Scheduled").owner
  end

  # ADR 009 had the job take every pane over the model's default scope,
  # because a relation cannot be serialised. That is the tenant's rows when
  # tenancy is enforced on the models and every row when it lives in a policy,
  # and Janela cannot tell which it is in: a policy scoped host was served
  # $150.00 live and published $375.00 from the snapshot beside it, under its
  # own name, answered 200 (#47). The job now refuses rather than choosing.
  test "the job refuses to freeze a scope it was not told" do
    error = assert_raises Janela::Unscoped do
      Janela::SnapshotJob.perform_now(name: "unanswered",
        panes: [ { "model" => "orders", "measure" => "revenue" } ])
    end

    assert_match "scope: :model_default", error.message
    assert_match "scope_for", error.message
    assert_equal 0, Janela::Snapshot.where(name: "unanswered").count
  end

  test "the job will not take a scope it does not know" do
    error = assert_raises ArgumentError do
      Janela::SnapshotJob.perform_now(name: "nonsense", scope: :whatever_you_reckon,
        panes: [ { "model" => "orders", "measure" => "revenue" } ])
    end

    assert_match "whatever_you_reckon", error.message
  end

  # The number is the assertion, not that a job ran: this issue was a snapshot
  # that answered 200 with somebody else's total in it.
  test "a subclass answers the question itself and freezes its own scope" do
    acme = customers(:acme)

    ScopedSnapshotJob.perform_now(name: "Acme only", owner: acme,
      panes: [ { "model" => "orders", "measure" => "revenue" } ])

    assert_equal 150.0, stored(Janela::Snapshot.find_by!(name: "Acme only"), Order, :revenue)
    assert_equal 375.0, Order.sum(:amount).to_f
  end

  # So a subclass never has to override perform or read ActiveJob's arguments
  # to find what it was told.
  test "a subclass can see the name, owner and filters the job was given" do
    seen = nil
    job = Class.new(Janela::SnapshotJob) do
      define_method(:scope_for) { |model| seen = [ name, owner, filters ]; model.all }
    end

    job.perform_now(name: "September", owner: customers(:acme), filters: { "status_eq" => "paid" },
      panes: [ { "model" => "orders", "measure" => "revenue" } ])

    assert_equal [ "September", customers(:acme), { "status_eq" => "paid" } ], seen
  end

  private
    def stored(snapshot, model, measure, **options)
      Janela::Query.new(definition: model.janela, measure: measure, dimension: options[:by],
                       granularity: options[:granularity], limit: options[:limit], snapshot: snapshot).result
    end
end
