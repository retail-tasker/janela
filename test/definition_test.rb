require "test_helper"

class DefinitionTest < ActiveSupport::TestCase
  test "a model without a janela block has no definition" do
    assert_nil Customer.janela
  end

  test "declares measures and dimensions" do
    assert_equal %i[revenue orders average_order], Order.janela.measures.keys
    assert_equal %i[status region customer channel placed_on], Order.janela.dimensions.keys
  end

  test "dimensions become the ransack allowlist" do
    assert_equal %w[status channel placed_on], Order.ransackable_attributes
    assert_equal %w[customer], Order.ransackable_associations
  end

  test "a model's own ransack allowlist is left alone" do
    assert_equal %w[region name], Customer.ransackable_attributes
  end

  test "rejects a measure without a single valid aggregate" do
    assert_raises(Janela::Error) { Janela::Measure.build(:bad, total: :amount) }
    assert_raises(Janela::Error) { Janela::Measure.build(:bad, sum: :amount, count: true) }
  end

  test "a dimension can be named for its meaning and read another column" do
    customer = Order.janela.dimensions[:customer]
    assert_equal :name, customer.column
    assert_equal "customer_name", customer.ransack_name
    assert_equal :region, Order.janela.dimensions[:region].column
  end

  test "a dimension with a granularity is a time dimension" do
    assert Order.janela.dimensions[:placed_on].time?
    assert_not Order.janela.dimensions[:status].time?
    assert_equal "day", Order.janela.dimensions[:placed_on].granularity
  end

  test "rejects an unknown granularity at declaration" do
    assert_raises(Janela::Error) { Janela::Dimension.new(:placed_on, model: Order, granularity: :fortnight) }
  end

  test "rejects a numeric aggregate over a boolean column" do
    error = assert_raises(Janela::Error) do
      Class.new(Order) do
        def self.name = "BooleanOrder"
        janela { measure :expedited_rate, average: :expedited }
      end
    end

    assert_match "expedited", error.message
    assert_match "dimension", error.message
  end

  test "counting a boolean column is allowed, since the answer is a number" do
    counted = Class.new(Order) do
      def self.name = "CountedOrder"
      janela { measure :orders, count: true }
    end

    assert_equal 4, counted.janela.query(:orders)
  end

  test "rejects a dimension through an unknown association" do
    assert_raises(Janela::Error) { Janela::Dimension.new(:name, model: Order, through: :vendor) }
  end
end
