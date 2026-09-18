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
    assert_equal %w[table bar line], Janela.renderers
  end

  test "granularities are a supported enumeration, not a constant a host reaches into" do
    assert_equal %w[hour day week month quarter year], Janela.granularities
  end

  test "offered limits are a supported enumeration, not a constant a host reaches into" do
    assert_equal [ 5, 10, 20, 50, 100 ], Janela.offered_limits
  end
end
