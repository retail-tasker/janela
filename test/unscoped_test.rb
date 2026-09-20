require "test_helper"

# ADR 032. Janela asks the host's controller what may be read and refuses if
# it has not been told, rather than answering with every row. The question
# lives in one place because it used to live in two and they disagreed (#46),
# so this is where both the controller and the helper are proven to refuse.
class UnscopedTest < ActiveSupport::TestCase
  # A host using a different authorisation library, or none at all.
  class BareController
    def self.name = "BareController"
  end

  # Pundit's own is protected, and docs/multi-tenancy.md teaches a private
  # method, so neither is public. Janela has to find both.
  class PrivateScopeController
    def self.name = "PrivateScopeController"

    private
      def policy_scope(model) = model.none
  end

  test "a controller that defines no policy_scope is refused" do
    assert_raises(Janela::Unscoped) { Janela.scope(BareController.new, Order) }
  end

  test "the refusal says what to define and where, because it is a setup mistake" do
    error = assert_raises(Janela::Unscoped) { Janela.scope(BareController.new, Order) }

    assert_match "BareController defines no policy_scope", error.message
    assert_match "Define it on ApplicationController", error.message
    assert_match "private def policy_scope(model) = model.all", error.message
    assert_match "Order", error.message
  end

  test "a private policy_scope is found and used" do
    assert_equal Order.none.to_sql, Janela.scope(PrivateScopeController.new, Order).to_sql
  end

  # The helper asks the controller rather than itself, so a frame rendered in
  # a host's own page refuses on the same terms as the engine's own pages.
  test "the helper refuses through the same question" do
    view = ActionView::Base.empty.extend(Janela::FramesHelper)
    view.define_singleton_method(:controller) { BareController.new }

    assert_raises(Janela::Unscoped) { view.send(:janela_scope, Order) }
  end
end
