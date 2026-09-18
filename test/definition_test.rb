require "test_helper"

class DefinitionTest < ActiveSupport::TestCase
  # Two of these declare a throwaway subclass to prove what the DSL rejects,
  # and declaring registers it. The registry outlives the test, so without
  # this a form that offers a choice of models would offer a class that only
  # ever existed in here, in whichever order the files happened to run.
  teardown do
    Janela.registry.delete_if { |_route_key, name| %w[BooleanOrder CountedOrder].include?(name) }
  end

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

  # Believed false: a dimension takes whatever predicate Ransack knows, since
  # nothing before this checked. ADR 025 found every one of Ransack's 62
  # predicates reachable and decided the allowlist is by kind of dimension.
  test "a category dimension allows only eq, in and null" do
    assert_equal %w[eq in null not_null], Order.janela.dimensions[:status].allowed_predicates
  end

  test "a time dimension additionally allows a range" do
    assert_equal %w[eq in null not_null gteq gt lteq lt], Order.janela.dimensions[:placed_on].allowed_predicates
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
      # A stand in for a model with a boolean column, not a kind of order:
      # orders is a single table inheritance table since the demo grew a
      # wholesale subclass, and a subclass of it would count its own rows,
      # of which a throwaway class has none.
      self.inheritance_column = nil
      janela { measure :orders, count: true }
    end

    assert_equal 4, counted.janela.query(:orders)
  end

  test "rejects a dimension through an unknown association" do
    assert_raises(Janela::Error) { Janela::Dimension.new(:name, model: Order, through: :vendor) }
  end
end
