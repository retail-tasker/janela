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
    error = assert_raises(Janela::Error) { Order.janela.query(:revenue, where: { customer_name_eq: "Acme" }) }
    assert_match "customer_name_eq", error.message
  end

  test "unknown measures and dimensions raise" do
    assert_raises(Janela::Error) { Order.janela.query(:profit) }
    assert_raises(Janela::Error) { Order.janela.query(:revenue, by: :colour) }
  end
end
