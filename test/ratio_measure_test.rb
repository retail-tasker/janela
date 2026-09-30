require "test_helper"

# ADR 038, #27. Believed (#20, #27): Rails casts an average of a boolean back
# to true, losing the ratio. Measured: it loses all of it, since 0.0 casts to
# true as well, so no ratio renders as anything else. The fixtures give two of
# four orders expedited: both paid, so paid is 100%, pending and refunded 0%.
class RatioMeasureTest < ActionDispatch::IntegrationTest
  def measure(**options)
    Janela::Measure.build(:rate, model: Order, **options)
  end

  test "a ratio is the fraction of rows where the boolean is true, as a number" do
    assert_equal 0.5, Order.janela.query(:expedited_rate)
    assert_not_equal true, Order.janela.query(:expedited_rate)
  end

  test "grouped, it is a fraction per bucket and the highest is first" do
    result = Order.janela.query(:expedited_rate, by: :status)

    assert_equal({ "paid" => 1.0, "pending" => 0.0, "refunded" => 0.0 }, result)
    assert_equal "paid", result.keys.first
  end

  test "through an association it groups and orders the same" do
    assert_equal({ "APAC" => 0.5, "EU" => 0.5 }, Order.janela.query(:expedited_rate, by: :region))
  end

  test "over time it buckets like any measure" do
    result = Order.janela.query(:expedited_rate, by: :placed_on, granularity: :day)

    assert_equal 1.0, result["2026-09-01"]
    assert_equal 0.0, result["2026-09-02"]
    assert_equal 1.0, result["2026-09-03"]
  end

  test "it cross-filters: a filter on another dimension narrows the rows it averages" do
    assert_equal 1.0, Order.janela.query(:expedited_rate, where: { "status_in" => [ "paid" ] })
    assert_equal 0.0, Order.janela.query(:expedited_rate, where: { "status_in" => [ "pending" ] })
  end

  test "the number is the fraction and the string is the percentage" do
    assert_equal "50.0%", measure(ratio: :expedited).format(0.5)
    assert_equal "31.2%", measure(ratio: :expedited).format(0.3119)
    assert_equal "0.0%", measure(ratio: :expedited).format(0.0)
    assert_equal "100.0%", measure(ratio: :expedited).format(1.0)
  end

  test "one decimal place by default, and a measure may say otherwise" do
    assert_equal "31%", measure(ratio: :expedited, precision: 0).format(0.3119)
    assert_equal "31.19%", measure(ratio: :expedited, precision: 2).format(0.3119)
  end

  test "an empty bucket renders as nothing, not as zero" do
    assert_equal "", measure(ratio: :expedited).format(nil)
  end

  test "a prefix or a suffix on a ratio raises, since the kind already says what unit it is" do
    error = assert_raises(Janela::Error) { measure(ratio: :expedited, suffix: "%") }
    assert_match "ratio", error.message
    assert_match "suffix", error.message
    assert_raises(Janela::Error) { measure(ratio: :expedited, prefix: "$") }
  end

  test "a ratio needs a boolean column, and says what it was given" do
    error = assert_raises(Janela::Error) { measure(ratio: :status) }
    assert_match "boolean", error.message
    assert_match "status", error.message
    assert_raises(Janela::Error) { measure(ratio: :no_such_column) }
    assert_raises(Janela::Error) { measure(ratio: true) }
  end

  test "it is one option beside the aggregates, not a second" do
    assert_raises(Janela::Error) { measure(ratio: :expedited, average: :amount) }
    assert_equal %i[sum count average minimum maximum], Janela::Measure::AGGREGATES
  end

  test "the refusal of an average over a boolean now names what to use" do
    error = assert_raises(Janela::Error) do
      Class.new(Order) do
        def self.name = "RatioRefusalOrder"
        janela { measure :expedited_rate, average: :expedited }
      end
    end

    assert_match "ratio: :expedited", error.message
    assert_match "dimension", error.message
  end

  test "a pane shows the percentage in a table and a single value" do
    get janela.pane_path("orders", "expedited_rate", "status")
    assert_select "caption", "Expedited rate by Status"
    assert_select "td", "100.0%"
    assert_select "td", "0.0%"

    get janela.pane_path("orders", "expedited_rate")
    assert_select ".janela-value-number", "50.0%"
  end

  test "a chart is drawn from the fractions and told the percentages" do
    get janela.pane_path("orders", "expedited_rate", "status", as: "bar")

    canvas = css_select("canvas").first
    assert_equal [ 1.0, 0.0, 0.0 ], JSON.parse(canvas["data-janela--chart-values-value"])
    assert_equal [ "100.0%", "0.0%", "0.0%" ], JSON.parse(canvas["data-janela--chart-formatted-value"])
  end

  test "a snapshot stores the fraction and reads back as a percentage" do
    snapshot = Janela::Snapshot.take(name: "September", owner: customers(:acme), taken_at: Time.utc(2026, 9, 15)) do |take|
      take.pane Order, :expedited_rate, by: :status
    end

    get janela.snapshot_pane_path(snapshot, "orders", "expedited_rate", "status")

    assert_select "td", "100.0%"
    assert_equal 1.0, snapshot.panes.first["result"]["paid"]
  end
end

# Null is not a failure: AVG leaves an unknown out and a ratio agrees with it.
# orders.expedited is NOT NULL, so this needs a column that may be.
class RatioNullTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.create_table(:ratio_probes, force: true) { |t| t.boolean :passed; t.string :kind }
    @probe = Class.new(ActiveRecord::Base) do
      def self.name = "RatioProbe"
      self.table_name = "ratio_probes"
      janela do
        measure :pass_rate, ratio: :passed
        dimension :kind
      end
    end
  end

  teardown do
    ActiveRecord::Base.connection.drop_table(:ratio_probes, if_exists: true)
    Janela.registry.delete("ratio_probes")
  end

  test "an unknown is left out, not counted as a failure" do
    [ true, false, nil ].each { |passed| @probe.create!(passed: passed, kind: "a") }

    assert_equal 0.5, @probe.janela.query(:pass_rate), "one true of the two known, not one of three"
  end

  test "a bucket of nothing but unknowns has no ratio" do
    @probe.create!(passed: nil, kind: "a")
    @probe.create!(passed: true, kind: "b")

    result = @probe.janela.query(:pass_rate, by: :kind)

    assert_nil result["a"]
    assert_equal 1.0, result["b"]
  end
end
