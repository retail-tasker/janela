require "test_helper"
require "open3"

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

  # Believed false: by the time anything asks HostRoutes.forwarded, the host's
  # routes have already been drawn. Route loading is lazy, so a cold process
  # sees an empty set instead, which is what a host calling this from its own
  # initializer would see too (issue #37). This suite's own process may
  # already have drawn routes by the time this test runs, so the cold case is
  # reproduced in a fresh process instead.
  test "forwarded is not empty from a cold process, before anything else has drawn routes" do
    script = <<~RUBY
      require "test_helper"
      puts Janela::HostRoutes.forwarded.include?("root_path")
    RUBY

    Dir.mktmpdir do |dir|
      script_path = File.join(dir, "repro.rb")
      File.write(script_path, script)

      out, status = Open3.capture2e({ "CI" => nil }, "ruby", "-Ilib:test:.", script_path,
                                     chdir: File.expand_path("..", __dir__))

      # test_helper pulls in rails/test_help, so minitest/autorun reports its
      # own, separate, empty run after the line this test cares about.
      assert status.success?, out
      assert_equal "true", out.lines.first.chomp
    end
  end
end
