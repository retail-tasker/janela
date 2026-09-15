require "test_helper"

# A value that validates but has no rule in the stylesheet renders unstyled and
# says nothing about it, so the two have to be asserted against each other
# (ADR 016).
class StylingTest < ActiveSupport::TestCase
  STYLESHEET = Janela::Engine.root.join("app/assets/stylesheets/janela.css").read

  test "every column count a frame allows has a rule, and nothing else does" do
    assert_equal Janela::Frame::COLUMNS.to_a, scales("cols")
  end

  test "every gap a frame allows has a rule, and nothing else does" do
    assert_equal Janela::Frame::GAPS.to_a, scales("gap")
  end

  test "every span a pane allows has a rule, and nothing else does" do
    assert_equal Janela::Pane::SPANS.to_a, scales("span")
  end

  test "the spacing scale has one base unit a host can retheme" do
    assert_match(/--janela-space:\s*0\.25rem/, STYLESHEET)
  end

  test "the hooks a pane renders with are styled" do
    %w[janela-frame janela-pane janela-value janela-empty janela-chart
       janela-page janela-heading janela-card janela-card-name janela-card-meta
       janela-subheading janela-flash janela-form janela-field janela-actions
       janela-button janela-errors janela-list janela-list-row janela-list-name
       janela-hint janela-muted janela-danger].each do |hook|
      assert_includes STYLESHEET, ".#{hook}", "#{hook} has no styling of its own"
    end
    assert_includes STYLESHEET, 'button[aria-pressed="true"]'
  end

  private
    def scales(property)
      STYLESHEET.scan(/\.janela-#{property}-(\d+)\s*\{/).flatten.map(&:to_i).sort
    end
end
