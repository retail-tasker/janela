require "test_helper"

class JanelaTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert Janela::VERSION
  end

  test "the engine is mounted in the host application" do
    Rails.application.reload_routes!
    assert_equal "/dashboards", Rails.application.routes.url_helpers.janela_path
  end
end
