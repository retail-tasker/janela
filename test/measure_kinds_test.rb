require "test_helper"

# ADR 064, #97. Three things a reporting page needs that a measure could not
# say: a count of distinct values, one sum over another, and a minimum of
# rows before a value is shown. Believed: each could be one more aggregate
# call. Measured: a ratio of sums nests aggregates and has to be two sums
# divided per key, and a minimum on a time pane cannot be a HAVING, because
# Groupdate then draws a shorter axis or none.
class MeasureKindsTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.create_table(:fact_probes, force: true) do |t|
      t.string :area
      t.integer :place_id
      t.integer :visits
      t.integer :target
      t.boolean :in_stock
      t.date :seen_on
    end
    @probe = Class.new(ActiveRecord::Base) do
      def self.name = "FactProbe"
      self.table_name = "fact_probes"
      janela do
        measure :rows, count: true
        measure :places, count_distinct: :place_id
        measure :to_target, ratio: :visits, over: :target
        measure :in_stock_rate, ratio: :in_stock, min_rows: 3
        measure :to_target_sampled, ratio: :visits, over: :target, min_rows: 3
        measure :average_visits, average: :visits, min_rows: 3
        dimension :area
        dimension :seen_on, granularity: :day
      end
    end
    day = Date.new(2026, 11, 2)
    # North: three rows, two places, 15 visits against 12, two of three in stock.
    @probe.create!(area: "North", place_id: 1, visits: 5, target: 4, in_stock: true, seen_on: day)
    @probe.create!(area: "North", place_id: 1, visits: 5, target: 4, in_stock: true, seen_on: day)
    @probe.create!(area: "North", place_id: 2, visits: 5, target: 4, in_stock: false, seen_on: day)
    # South: three rows, one place, 6 visits against 12, one in stock.
    @probe.create!(area: "South", place_id: 3, visits: 2, target: 4, in_stock: true, seen_on: day)
    @probe.create!(area: "South", place_id: 3, visits: 2, target: 4, in_stock: false, seen_on: day)
    @probe.create!(area: "South", place_id: 3, visits: 2, target: 4, in_stock: false, seen_on: day)
    # West: one row, a target of zero, and too few rows for a minimum.
    @probe.create!(area: "West", place_id: 4, visits: 1, target: 0, in_stock: true, seen_on: day + 2)
  end

  teardown do
    ActiveRecord::Base.connection.drop_table(:fact_probes, if_exists: true)
    Janela.registry.delete("fact_probes")
  end

  def query(measure, **options)
    @probe.janela.query(measure, **options)
  end

  def pane(measure, **options)
    Janela::Query.new(definition: @probe.janela, measure: measure, **options)
  end

  def declare(**options)
    Janela::Definition.new(@probe) { measure :probe, **options }
  end

  # count_distinct

  test "count_distinct counts distinct values, grouped, over time and as one figure" do
    assert_equal({ "North" => 2, "South" => 1, "West" => 1 }, query(:places, by: :area))
    assert_equal 4, query(:places)
    assert_equal [ 3, 0, 1 ], query(:places, by: :seen_on).values
  end

  test "count_distinct orders by its count and reads as a whole number" do
    assert_equal [ "South", "West" ], query(:places, by: :area, sort: "asc", limit: 2).keys
    assert_equal "2", @probe.janela.measure!(:places).format(2)
  end

  test "count_distinct does not add up, so a running total of it is refused" do
    error = assert_raises(Janela::BadRequest) { pane(:places, dimension: :seen_on, renderer: "line", cumulative: "1") }
    assert_match(/count of distinct values/, error.message)
  end

  # ratio over

  test "a ratio of two sums divides the sums per group and is never clamped" do
    result = query(:to_target, by: :area)

    assert_in_delta 1.25, result["North"]
    assert_in_delta 0.5, result["South"]
    assert_in_delta 22.0 / 24, query(:to_target)
    assert_equal "125.0%", @probe.janela.measure!(:to_target).format(result["North"])
  end

  test "a group whose denominator sums to zero has no value, and sorts after those that have one" do
    assert_nil query(:to_target, by: :area)["West"]
    assert_equal [ "North", "South", "West" ], query(:to_target, by: :area).keys
    assert_equal [ "South", "North", "West" ], query(:to_target, by: :area, sort: "asc").keys
  end

  test "a ratio of two sums over time has no value in an empty bucket rather than an error" do
    result = query(:to_target, by: :seen_on)

    assert_equal 3, result.size
    assert_in_delta 21.0 / 24, result.values.first
    assert_nil result.values.second
    assert_nil result.values.third, "a zero target is no value, not infinity"
  end

  test "both columns of a ratio of sums must be numeric, checked at declaration" do
    assert_raises(Janela::Error) { declare(ratio: :area, over: :target) }
    assert_raises(Janela::Error) { declare(ratio: :visits, over: :in_stock) }
    assert_raises(Janela::Error) { declare(sum: :visits, over: :target) }
  end

  test "a ratio of two sums does not add up, so a running total of it is refused" do
    assert_raises(Janela::BadRequest) { pane(:to_target, dimension: :seen_on, renderer: "line", cumulative: "1") }
  end

  # min_rows

  test "min_rows is refused on a measure that is true however few rows it is over" do
    [ { sum: :visits }, { count: true }, { count_distinct: :place_id } ].each do |aggregate|
      error = assert_raises(Janela::Error) { declare(**aggregate, min_rows: 3) }
      assert_match(/min_rows/, error.message)
    end
    assert_raises(Janela::Error) { declare(average: :visits, min_rows: 0) }
    assert_raises(Janela::Error) { declare(average: :visits, min_rows: "lots") }
  end

  test "a category group under the minimum is left out before the sort and the limit" do
    assert_equal [ "North", "South" ], query(:in_stock_rate, by: :area).keys
    # The bottom one is South, not West: West has one row and is never a candidate.
    assert_equal [ "South" ], query(:in_stock_rate, by: :area, sort: "asc", limit: 1).keys
    assert_equal [ "North", "South" ], query(:to_target_sampled, by: :area).keys
  end

  test "a time bucket under the minimum has no value, and the axis is the same length" do
    result = query(:average_visits, by: :seen_on)

    assert_equal 3, result.size
    assert_in_delta 3.5, result.values.first
    assert_nil result.values.third, "one row is under the minimum of three"
  end

  test "a single value under the minimum has no value" do
    on = @probe.where(area: "West")

    assert_nil query(:in_stock_rate, on: on)
    assert_in_delta 4.0 / 7, query(:in_stock_rate)
  end

  test "no value reads as a dash, the same for an empty bucket and a suppressed one" do
    assert_equal "–", @probe.janela.measure!(:in_stock_rate).format(nil)
    assert_equal "–", @probe.janela.measure!(:places).format(nil)
  end

  # show_under_min_rows

  test "a pane that keeps groups under the minimum lists them without a value, after every group that qualified" do
    desc = query(:in_stock_rate, by: :area, show_under_min_rows: true)
    asc = query(:in_stock_rate, by: :area, sort: "asc", show_under_min_rows: true)

    assert_equal [ "North", "South", "West" ], desc.keys
    assert_equal [ "South", "North", "West" ], asc.keys
    assert_nil desc["West"]
  end

  test "groups kept under the minimum sort among themselves by label, not by their value" do
    @probe.create!(area: "East", place_id: 5, visits: 1, target: 1, in_stock: false, seen_on: Date.new(2026, 11, 2))

    assert_equal [ "North", "South", "East", "West" ], query(:in_stock_rate, by: :area, show_under_min_rows: true).keys
    assert_equal [ "South", "North", "East", "West" ], query(:in_stock_rate, by: :area, sort: "asc", show_under_min_rows: true).keys
  end

  test "a limit fills with groups that qualified before any that did not" do
    assert_equal [ "South" ], query(:in_stock_rate, by: :area, sort: "asc", limit: 1, show_under_min_rows: true).keys
  end

  test "the pane option reaches the query, and a time pane and a measure with no minimum ignore it" do
    kept = pane(:in_stock_rate, dimension: :area, show_under_min_rows: "1").result(on: @probe.all)

    assert_equal [ "North", "South", "West" ], kept.keys
    assert_equal 3, pane(:average_visits, dimension: :seen_on, renderer: "line", show_under_min_rows: "1").result(on: @probe.all).size
    assert_equal 3, pane(:rows, dimension: :area, show_under_min_rows: "1").result(on: @probe.all).size
    assert_raises(Janela::BadRequest) { pane(:in_stock_rate, dimension: :area, show_under_min_rows: "maybe") }
  end
end
