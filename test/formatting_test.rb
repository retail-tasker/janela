require "test_helper"

# What a number means is declared with the measure, so these read the measure
# directly rather than through a pane (ADR 020).
class FormattingTest < ActiveSupport::TestCase
  test "counting rows has no decimal places" do
    assert_equal "4", measure(count: true).format(4)
  end

  test "a decimal column's own scale is the default precision" do
    assert_equal "375.00", measure(sum: :amount).format(375)
    assert_equal "928.88", measure(average: :amount).format(928.8767833333333)
  end

  test "summing an integer column stays whole" do
    assert_equal "1,234", measure(sum: :id).format(1234)
  end

  test "averaging an integer column does not, since the answer is a ratio" do
    assert_equal "66.67", measure(average: :id).format(66.66666)
  end

  test "a declared precision beats the schema" do
    assert_equal "929", measure(sum: :amount, precision: 0).format(928.8767833333333)
    assert_equal "928.877", measure(sum: :amount, precision: 3).format(928.8767833333333)
  end

  test "a prefix and a suffix carry the unit, which no amount of rounding can say" do
    assert_equal "$375.00", measure(sum: :amount, prefix: "$").format(375)
    assert_equal "66.7%", measure(average: :id, precision: 1, suffix: "%").format(66.66666)
  end

  test "thousands are delimited, and a host's locale says with what" do
    assert_equal "1,234,567.50", measure(sum: :amount).format(1234567.5)
  end

  test "a precision that is not a number of decimal places is rejected at declaration" do
    error = assert_raises(Janela::Error) { measure(sum: :amount, precision: 11) }
    assert_match "0 to 10", error.message

    assert_raises(Janela::Error) { measure(sum: :amount, precision: "two") }
  end

  test "a measure with nothing to show renders nothing rather than zero" do
    assert_equal "", measure(sum: :amount).format(nil)
  end

  test "a value that is not a number is left as it is, since minimum of a string is a string" do
    assert_equal "paid", measure(minimum: :status).format("paid")
  end

  test "a pane formats every number it renders the same way" do
    query = Janela::Query.new(definition: Order.janela, measure: :revenue, dimension: :status)

    assert_equal "$300.00", query.format(300)
  end

  test "a snapshot stores the number, so a format declared later still applies" do
    snapshot = Janela::Snapshot.take(name: "September") { |take| take.pane Order, :revenue }
    stored = Janela::Query.new(definition: Order.janela, measure: :revenue, snapshot: snapshot).result

    assert_kind_of Numeric, stored, "a stored result is data, and formatting is rendering (ADR 009)"
  end

  private
    def measure(**options)
      Janela::Measure.build(:measured, model: Order, **options)
    end
end
