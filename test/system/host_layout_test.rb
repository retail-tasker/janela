require "application_system_test_case"

# ADR 011 kept a pane's Turbo Frame request bare and put a directly opened
# pane in Janela's own minimal layout, because a host layout's route helper
# used to raise inside the isolated engine. ADR 022 forwards the host's route
# helpers into the engine, so the demo points the engine's own pages at its
# own layout instead (see the initializer in test/dummy), and this is the
# page ADR 011 was written about.
class HostLayoutTest < ApplicationSystemTestCase
  setup { @frame = janela_frames(:orders) }

  test "the engine's own frame page renders inside the host's layout" do
    visit janela.frame_path(@frame)

    within("nav") { assert_text "Dashboards" }
    assert_selector "footer#site-footer"
  end
end
