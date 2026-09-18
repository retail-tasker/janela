require "test_helper"

# ADR 031, issue #11. The issue said a subclass of a model with a janela block
# gets nil from .janela and is not registered, and both were true. What it
# missed is the half that already inherited: the allowlist was defined as
# singleton methods on the parent, and singleton methods inherit, so a
# subclass came out filterable on dimensions that no definition behind it
# declared. Neither half was decided. One was written and the other happened.
# These tests exist to keep both halves saying the same thing.
class SubclassTest < ActiveSupport::TestCase
  setup { @registry = Janela.registry.dup }

  # Whatever a test declared, the registry goes back to what it was: a test
  # that fails after registering something must not leave the rest of the
  # suite reading a registry it did not expect.
  teardown do
    Janela.registry.replace(@registry)
    %i[CountingOrder TradeOrder ReloadableOrder TradeAccountOrder CashTradeOrder].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
    end
  end

  test "a subclass reports the dashboard its parent declared" do
    assert_equal Order.janela.measures.keys, WholesaleOrder.janela.measures.keys
    assert_equal Order.janela.dimensions.keys, WholesaleOrder.janela.dimensions.keys
  end

  # The declaration inherits rather than the definition object. A definition
  # holds the model it queries, so a subclass handed its parent's object would
  # report the dashboard and then total the parent's rows behind it.
  test "a subclass's definition queries the subclass" do
    assert_equal WholesaleOrder, WholesaleOrder.janela.model
  end

  test "a subclass is registered under its own route key" do
    assert_equal "WholesaleOrder", Janela.registry["wholesale_orders"]
    assert_equal WholesaleOrder, Janela.definition!("wholesale_orders").model
  end

  # ADR 031 claims ActiveRecord adds the type condition itself and Janela
  # learns nothing about STI. This is the test that says whether that is true:
  # the fixtures make Globex's two orders wholesale, so the subclass is 225 of
  # its parent's 375.
  test "a subclass totals its own rows rather than its parent's" do
    assert_equal 375.0, Order.janela.query(:revenue).to_f
    assert_equal 225.0, WholesaleOrder.janela.query(:revenue).to_f
  end

  test "a subclass groups its own rows" do
    assert_equal({ "paid" => 300.0, "refunded" => 50.0, "pending" => 25.0 },
                 Order.janela.query(:revenue, by: :status).transform_values(&:to_f))
    assert_equal({ "paid" => 200.0, "pending" => 25.0 },
                 WholesaleOrder.janela.query(:revenue, by: :status).transform_values(&:to_f))
  end

  # The honest cost ADR 031 names: a subclass appears wherever definitions are
  # offered, which is the form an analyst adds a pane with (ADR 012), so a
  # host with a dozen STI types sees a dozen entries where it expected one.
  test "a subclass is offered wherever a definition is" do
    assert_includes Janela.definitions.map(&:model), WholesaleOrder
  end

  test "a pane row may name a subclass" do
    pane = janela_frames(:orders).panes.build(model: "wholesale_orders", measure: "revenue", dimension: "status")

    assert pane.valid?, pane.errors.full_messages.to_sentence
  end

  test "a subclass that declares its own block gets its own definition" do
    declare <<~RUBY
      class CountingOrder < Order
        janela do
          measure :orders, count: true
          dimension :channel
        end
      end
    RUBY

    assert_equal %i[orders], CountingOrder.janela.measures.keys
    assert_equal %i[channel], CountingOrder.janela.dimensions.keys
    assert_equal CountingOrder, CountingOrder.janela.model
    assert_equal %i[revenue orders average_order], Order.janela.measures.keys
  end

  # The half that inherited by accident: the allowlist arrived from the parent
  # while .janela returned nil, so a host calling WholesaleOrder.ransack(...)
  # in its own code got the parent's dimensions from a class that reported no
  # definition, and nothing explained why.
  test "a subclass filters on the dimensions of the definition it reports" do
    assert_equal WholesaleOrder.janela.ransackable_attributes, WholesaleOrder.ransackable_attributes
    assert_equal WholesaleOrder.janela.ransackable_associations, WholesaleOrder.ransackable_associations
  end

  test "a subclass with its own block filters on its own dimensions" do
    declare <<~RUBY
      class CountingOrder < Order
        janela do
          measure :orders, count: true
          dimension :channel
        end
      end
    RUBY

    assert_equal %w[channel], CountingOrder.ransackable_attributes
    assert_equal %w[status channel placed_on], Order.ransackable_attributes
  end

  # A host that writes its own allowlist keeps it, which is the rule the gem
  # has always stated. A subclass declaring a janela block must not quietly
  # replace what the host wrote a class up.
  test "a subclass does not take the allowlist a host wrote on its parent" do
    declare <<~RUBY
      class TradeAccountOrder < Order
        def self.ransackable_attributes(_auth_object = nil) = %w[status]
      end

      class CashTradeOrder < TradeAccountOrder
        janela do
          measure :orders, count: true
          dimension :channel
        end
      end
    RUBY

    assert_equal %w[status], CashTradeOrder.ransackable_attributes
  end

  # A host may give a subclass its parent's model_name, so the two share a
  # route and a form. Registering under that key would repoint the parent's
  # own URL at a subset of its rows, and nothing on the page would say so.
  test "a subclass does not take a route key another class already holds" do
    declare <<~RUBY
      class TradeOrder < Order
        def self.model_name = Order.model_name
      end
    RUBY

    assert_equal "Order", Janela.registry["orders"]
    assert_equal Order, Janela.definition!("orders").model
  end

  # Why the registry stores names rather than classes: a class replaced by a
  # reload in development leaves nothing stale behind, because the key
  # resolves to whatever the constant is now rather than to the object that
  # registered under it.
  test "a subclass replaced by a reload leaves nothing stale behind" do
    declare "class ReloadableOrder < Order; end"
    first = ReloadableOrder
    Object.send(:remove_const, :ReloadableOrder)
    declare "class ReloadableOrder < Order; end"

    assert_not_same first, ReloadableOrder
    assert_equal 1, Janela.registry.count { |_route_key, name| name == "ReloadableOrder" }
    assert_same ReloadableOrder, Janela.definition!("reloadable_orders").model
  end

  private
    # A subclass has to be declared the way a host declares one. Class.new is
    # anonymous while inherited runs, and a class with no name has no route
    # key to be registered under.
    def declare(source)
      Object.class_eval(source, __FILE__, __LINE__)
    end
end
