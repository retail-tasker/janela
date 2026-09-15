require "test_helper"

class QueryTest < ActiveSupport::TestCase
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
