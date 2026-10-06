require "test_helper"

class JanelaTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert Janela::VERSION
  end

  test "the engine is mounted in the host application" do
    Rails.application.reload_routes!
    assert_equal "/dashboards", Rails.application.routes.url_helpers.janela_path
  end

  # A gallery had no way to ask what Janela can draw without reading
  # Janela::Query::RENDERERS, Janela::Dimension::GRANULARITIES or
  # Janela::Pane::OFFERED_LIMITS directly, which is exactly what ADR 027
  # says a host page must not do (#39).
  test "renderers are a supported enumeration, not a constant a host reaches into" do
    assert_equal %w[table bar line doughnut pie], Janela.renderers
  end

  test "granularities are a supported enumeration, not a constant a host reaches into" do
    assert_equal %w[hour day week month quarter year], Janela.granularities
  end

  test "offered limits are a supported enumeration, not a constant a host reaches into" do
    assert_equal [ 5, 10, 20, 50, 100 ], Janela.offered_limits
  end

  # The playground in the demo's gallery offers a pane's height, prominence and
  # companions as controls, which it cannot do without asking (ADR 027). Held
  # against the values a pane is validated with, so the control never offers a
  # step the pane then refuses.
  test "the steps a pane takes are a supported enumeration, and are the ones it validates against" do
    assert_equal [ 1, 2, 3, 4, 5 ], Janela.heights
    assert_equal [ 1, 2, 3 ], Janela.prominences
    assert_equal 3, Janela.max_companions
    assert_equal Janela::Pane::HEIGHTS.to_a, Janela.heights
    assert_equal Janela::Query::PROMINENCES.to_a, Janela.prominences
  end
end
