require "test_helper"

# ADR 049, #69. Believed (ADR 024): a value and the null group cannot be asked
# for together, because Ransack ANDs them and returns nothing. True of the
# parameters as Ransack reads them, and not the end of it: read as a union,
# which Ransack's own grouping expresses, the pair is an ordinary selection.
# Orders by channel in the fixtures: web 2, phone 1, and one with none.
class NullSelectionTest < ActionDispatch::IntegrationTest
  def orders(where)
    Order.janela.query(:orders, where: where)
  end

  test "a value and the null group together are the union, not the intersection" do
    assert_equal 3, orders("channel_in" => [ "web" ], "channel_null" => "1")
  end

  test "_eq and the null group are the union too, since a shared link may carry either" do
    assert_equal 3, orders("channel_eq" => "web", "channel_null" => "1")
  end

  test "the union meets every other filter with AND" do
    both = orders("channel_in" => [ "web" ], "channel_null" => "1", "status_in" => [ "paid" ])

    assert_equal 2, both, "web or none, and paid: two paid web orders"
  end

  test "through an association the join survives the union" do
    assert_equal 2, orders("customer_region_in" => [ "APAC" ], "customer_region_null" => "1")
  end

  test "the null group alone and a value alone are what they were" do
    assert_equal 1, orders("channel_null" => "1")
    assert_equal 2, orders("channel_in" => [ "web" ])
  end

  # The union must not become a way round what ADR 025 bounds.
  test "the value ceiling still applies to a value beside the null group" do
    assert_raises(Janela::BadRequest) { orders("channel_in" => Array.new(1001) { |i| "v#{i}" }, "channel_null" => "1") }
  end

  test "a predicate that is not allowed is still refused beside the null group" do
    assert_raises(Janela::BadRequest) { orders("channel_matches" => "%", "channel_null" => "1") }
  end

  # An inclusion and the null group are two ways of being selected, so they
  # OR. Two exclusions are two ways of being ruled out, so they AND.
  test "exclusions still intersect: not in a value, and not none" do
    assert_equal 2, orders("channel_not_in" => [ "phone" ], "channel_not_null" => "1")
  end

  test "the null group and not-null together are a contradiction and match nothing" do
    assert_equal 0, orders("channel_null" => "1", "channel_not_null" => "1")
  end

  test "a host's where and a frame's default_where read the pair as a union as well" do
    assert_equal 3, Order.janela.narrow(Order.all, "channel_in" => [ "web" ], "channel_null" => "1").count
  end

  test "a pane's URL with the pair shows the union" do
    get janela.pane_path("orders", "orders", q: { channel_in: [ "web" ], channel_null: "1" })

    assert_select ".janela-value-number", "3"
  end

  test "the channel pane ignores its own selection and marks both members of it" do
    get janela.pane_path("orders", "orders", "channel", q: { channel_in: [ "web" ], channel_null: "1" })

    assert_select "button[aria-pressed=true]", 2
    assert_select "button[aria-pressed=true]", "web"
    assert_select "button[aria-pressed=true]", "(none)"
    assert_select "button[aria-pressed=false]", "phone"
  end
end
