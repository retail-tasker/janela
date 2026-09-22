require "test_helper"

# Believed false: a host model with a column or a method named janela collides
# with Janela's, and Janela takes something away from the host (#12).
#
# A column does not collide at all: attribute methods are instance methods and
# Janela's is a class method, so the two never meet. A class method does, and
# the host's wins, as Ruby says it should, because it sits on its own
# singleton and Janela's module is extended onto ActiveRecord::Base's. So
# Janela loses the argument rather than the host.
#
# What went wrong was the other direction. Janela believed anything truthy
# that came back from .janela was its own definition, so a host answering that
# question for its own reasons crashed the doctor, registered a subclass and
# put a String among Janela.definitions (#54).
class HostCollisionTest < ActiveSupport::TestCase
  setup { @registry = Janela.registry.dup }

  teardown do
    Janela.registry.replace(@registry)
    %i[Gadget PremiumGadget Widget].each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
    end
    ActiveRecord::Base.connection.drop_table(:widgets, if_exists: true)
  end

  test "the doctor ignores a model whose janela is not one of ours" do
    a_host_that_answers_janela

    findings = Janela::Doctor.new(Rails.root).check

    assert_kind_of Array, findings, "the doctor ran at all"
    assert_empty findings.map(&:summary).grep(/Gadget/)
  end

  test "a definition Janela did not build is not offered as one" do
    a_host_that_answers_janela
    a_named_subclass_of_it

    assert(Janela.definitions.all? { |definition| definition.is_a?(Janela::Definition) },
      "Janela.definitions handed out something that is not a definition")
  end

  test "a subclass of it is not registered, so no URL resolves to it" do
    a_host_that_answers_janela
    a_named_subclass_of_it

    assert_not_includes Janela.registry.keys, "premium_gadgets"
    assert_raises(Janela::NotFound) { Janela.definition!("premium_gadgets") }
  end

  # The half of #12 that turned out to be false, kept so nobody fixes it.
  test "a column named janela is left alone, because it is an instance method" do
    ActiveRecord::Base.connection.create_table(:widgets, force: true) do |t|
      t.string :janela
      t.integer :amount
    end
    eval(<<~RUBY, TOPLEVEL_BINDING)
      class Widget < ActiveRecord::Base
        janela { measure :total, sum: :amount }
      end
    RUBY
    Widget.create!(janela: "a window", amount: 3)

    assert_equal "a window", Widget.first.janela, "the host's own column still reads"
    assert_equal [ :total ], Widget.janela.measures.keys, "and the dashboard is still declared"
  end

  private
    # A real class definition rather than Class.new: a subclass only carries a
    # name inside `inherited` when it was created by the `class X < Y` form,
    # and the name is what decides whether it registers at all (ADR 031).
    def a_host_that_answers_janela
      # TOPLEVEL_BINDING, or the class is defined under this test rather than
      # at the top level, and registers under a route key no host would have.
      eval(<<~RUBY, TOPLEVEL_BINDING)
        class Gadget < ActiveRecord::Base
          self.table_name = "customers"
          def self.janela = "the host's own answer"
        end
      RUBY
    end

    def a_named_subclass_of_it
      eval("class PremiumGadget < Gadget; end", TOPLEVEL_BINDING)
    end
end
