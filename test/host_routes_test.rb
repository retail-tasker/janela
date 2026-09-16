require "test_helper"

# isolate_namespace makes a bare route helper inside Janela's controllers
# resolve against the engine's routes, and a host's own ApplicationController
# runs there (ADR 022).
class HostRoutesTest < ActionDispatch::IntegrationTest
  test "a host's own redirect works inside the engine, without knowing it is inside an engine" do
    get janela.pane_path("orders", "revenue", "status"), params: { locked: 1 }

    assert_redirected_to "/"
  end

  test "the same redirect works outside the engine, which is the comparison" do
    get root_path, params: { locked: 1 }

    assert_redirected_to "/"
  end

  test "a name the engine defines is its own, so a host's route of that name cannot shadow it" do
    # The dummy has resources :frames of its own, at /frames.
    assert_not_includes Janela::HostRoutes.forwarded, "frames_path"
    assert_includes Janela::HostRoutes.forwarded, "root_path"

    get janela.frame_path(janela_frames(:orders))

    assert_select "a.janela-crumb, .janela-crumb a" do |links|
      assert_equal "/dashboards/", links.first["href"], "the crumb is the engine's index, not the host's /frames"
    end
  end

  test "host route helpers work in a view the engine renders, not only in its controllers" do
    controller = Janela::FramesController.new
    controller.request = ActionDispatch::TestRequest.create

    assert_equal "/", controller.view_context.root_path
  end
end
