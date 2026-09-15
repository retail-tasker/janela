require "test_helper"

class DefinitionTest < ActiveSupport::TestCase
  test "a model without a janela block has no definition" do
    assert_nil Customer.janela
  end

  test "declares measures and dimensions" do
    assert_equal %i[revenue orders average_order], Order.janela.measures.keys
    assert_equal %i[status region placed_on], Order.janela.dimensions.keys
  end

  test "dimensions become the ransack allowlist" do
    assert_equal %w[status placed_on], Order.ransackable_attributes
    assert_equal %w[customer], Order.ransackable_associations
  end

  test "a model's own ransack allowlist is left alone" do
    assert_equal %w[region], Customer.ransackable_attributes
  end

  test "rejects a measure without a single valid aggregate" do
    assert_raises(Janela::Error) { Janela::Measure.build(:bad, total: :amount) }
    assert_raises(Janela::Error) { Janela::Measure.build(:bad, sum: :amount, count: true) }
  end

  test "rejects a dimension through an unknown association" do
    assert_raises(Janela::Error) { Janela::Dimension.new(:name, model: Order, through: :vendor) }
  end
end
