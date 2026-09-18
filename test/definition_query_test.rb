require "test_helper"

# Definition#query, which is not Janela::Query: this covers the method that
# builds and runs the aggregate, not the object that carries a pane's request.
class DefinitionQueryTest < ActiveSupport::TestCase
  test "a measure with no dimension is a single value" do
    assert_equal 375, Order.janela.query(:revenue)
    assert_equal 4, Order.janela.query(:orders)
  end

  test "a measure by a dimension on the model" do
    assert_equal({ "paid" => 300, "refunded" => 50, "pending" => 25 }, Order.janela.query(:revenue, by: :status))
  end

  test "a measure by a dimension through an association" do
    assert_equal({ "APAC" => 150, "EU" => 225 }, Order.janela.query(:revenue, by: :region))
  end

  test "a null group is labelled rather than blank" do
    assert_equal({ "web" => 300, "(none)" => 25, "phone" => 50 }, Order.janela.query(:revenue, by: :channel))
  end

  test "the null group is filtered with the null predicate, not an empty string" do
    assert_equal 25, Order.janela.query(:revenue, where: { channel_null: "1" })
    assert_equal 350, Order.janela.query(:revenue, where: { channel_not_null: "1" })
  end

  test "a category breakdown is ordered by the measure, largest first" do
    assert_equal %w[paid refunded pending], Order.janela.query(:revenue, by: :status).keys
    assert_equal %w[EU APAC], Order.janela.query(:revenue, by: :region).keys
  end

  test "a limit keeps the top rows and is applied in SQL" do
    assert_equal({ "paid" => 300, "refunded" => 50 }, Order.janela.query(:revenue, by: :status, limit: 2))
    assert_equal({ "paid" => 300 }, Order.janela.query(:revenue, by: :status, limit: "1"))
  end

  test "a limit outside 1 to 1000 raises" do
    assert_raises(Janela::Error) { Order.janela.query(:revenue, by: :status, limit: 0) }
    assert_raises(Janela::Error) { Order.janela.query(:revenue, by: :status, limit: "ten") }
  end

  test "time buckets stay chronological and ignore a limit" do
    assert_equal %w[2026-09-01 2026-09-02 2026-09-03 2026-09-04],
      Order.janela.query(:revenue, by: :placed_on, limit: 2).keys
  end

  test "an aliased through dimension groups and filters by its column" do
    assert_equal({ "Acme" => 150, "Globex" => 225 }, Order.janela.query(:revenue, by: :customer))
    assert_equal 225, Order.janela.query(:revenue, where: { customer_name_eq: "Globex" })
  end

  test "filters are ransack params" do
    assert_equal 300, Order.janela.query(:revenue, where: { status_eq: "paid" })
    assert_equal 325, Order.janela.query(:revenue, where: { status_in: %w[paid pending] })
  end

  test "filters through an association" do
    assert_equal({ "paid" => 1, "refunded" => 1 },
      Order.janela.query(:orders, by: :status, where: { customer_region_eq: "APAC" }))
  end

  test "filters and groups on the same association" do
    assert_equal({ "EU" => 225 }, Order.janela.query(:revenue, by: :region, where: { customer_region_eq: "EU" }))
  end

  test "scopes to a relation supplied by the host" do
    assert_equal 150, Order.janela.query(:revenue, on: Order.joins(:customer).where(customers: { region: "APAC" }))
  end

  test "a filter the allowlist rejects raises instead of returning unfiltered numbers" do
    error = assert_raises(Janela::Error) { Order.janela.query(:revenue, where: { customer_created_at_eq: "2026-01-01" }) }
    assert_match "customer_created_at_eq", error.message
  end

  # Believed false, until ADR 025 measured it: every one of Ransack's 62
  # predicates worked on an allowed attribute, including a leading-wildcard
  # _matches scan. A dashboard filter is now allowed by kind of dimension.
  test "a predicate outside a categorical dimension's allowlist raises loudly rather than being dropped" do
    error = assert_raises(Janela::BadRequest) { Order.janela.query(:revenue, where: { status_cont: "pai" }) }
    assert_match "status_cont", error.message

    error = assert_raises(Janela::BadRequest) { Order.janela.query(:revenue, where: { status_matches: "%aid" }) }
    assert_match "status_matches", error.message
  end

  test "a categorical dimension through an association is bound the same way" do
    error = assert_raises(Janela::BadRequest) { Order.janela.query(:revenue, where: { customer_name_cont: "cm" }) }
    assert_match "customer_name_cont", error.message
  end

  test "a time dimension keeps its documented range predicates" do
    assert_equal 150, Order.janela.query(:revenue, where: { placed_on_gteq: "2026-09-01", placed_on_lt: "2026-09-03" })
  end

  test "a predicate outside a time dimension's allowlist still raises" do
    error = assert_raises(Janela::BadRequest) { Order.janela.query(:revenue, where: { placed_on_matches: "2026%" }) }
    assert_match "placed_on_matches", error.message
  end

  test "a single filter may not carry more than 1000 values" do
    error = assert_raises(Janela::BadRequest) { Order.janela.query(:revenue, where: { status_in: (1..1001).map(&:to_s) }) }
    assert_match "1000", error.message
  end

  test "a category breakdown gets a default ceiling of 1000 when no limit is given" do
    Order.insert_all((1..1001).map { |n| { customer_id: customers(:acme).id, status: "s#{n}", amount: 1,
                                            placed_on: Date.new(2026, 9, 1), channel: "web",
                                            created_at: Time.current, updated_at: Time.current } })

    assert_equal 1000, Order.janela.query(:revenue, by: :status).size
  end

  test "a time dimension buckets by its declared granularity with labels" do
    assert_equal({ "2026-09-01" => 100, "2026-09-02" => 50, "2026-09-03" => 200, "2026-09-04" => 25 },
      Order.janela.query(:revenue, by: :placed_on))
  end

  test "granularity can be widened at query time" do
    assert_equal({ "Sep 2026" => 375 }, Order.janela.query(:revenue, by: :placed_on, granularity: :month))
    assert_equal({ "Q3 2026" => 375 }, Order.janela.query(:revenue, by: :placed_on, granularity: "quarter"))
    assert_equal({ "2026" => 4 }, Order.janela.query(:orders, by: :placed_on, granularity: :year))
  end

  test "time buckets respect filters and fill gaps" do
    assert_equal({ "2026-09-01" => 100, "2026-09-02" => 50 },
      Order.janela.query(:revenue, by: :placed_on, where: { customer_region_eq: "APAC" }))
    assert_equal({ "2026-09-01" => 100, "2026-09-02" => 0, "2026-09-03" => 200 },
      Order.janela.query(:revenue, by: :placed_on, where: { status_eq: "paid" }))
  end

  test "an unknown granularity raises" do
    assert_raises(Janela::Error) { Order.janela.query(:revenue, by: :placed_on, granularity: :fortnight) }
  end

  test "unknown measures and dimensions raise" do
    assert_raises(Janela::Error) { Order.janela.query(:profit) }
    assert_raises(Janela::Error) { Order.janela.query(:revenue, by: :colour) }
  end
end
