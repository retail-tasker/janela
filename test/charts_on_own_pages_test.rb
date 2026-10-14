require "test_helper"

# ADR 059: the engine's frame page draws a chart pane as a table unless the host
# has said its layout loads the runtime, because the engine cannot see that and
# a guess would leave an empty hole where a table was (ADR 018).
class ChartsOnOwnPagesTest < ActionDispatch::IntegrationTest
  setup { @was = Janela.charts_on_own_pages }
  teardown { Janela.charts_on_own_pages = @was }

  test "a host that says nothing gets the table, as before" do
    Janela.charts_on_own_pages = false

    get janela.frame_path(janela_frames(:orders))

    assert_select "table.janela-pane caption", "Revenue by Status"
    assert_select "canvas", false
  end

  test "a host that says its layout draws charts gets the chart" do
    Janela.charts_on_own_pages = true

    get janela.frame_path(janela_frames(:orders))

    assert_select "canvas"
    assert_select "table.janela-pane caption", text: "Revenue by Status", count: 0
    # Its neighbour is a table on purpose and stays one.
    assert_select "table.janela-pane caption", "Where the money is"
  end

  test "a value and a table pane are drawn the same either way" do
    Janela.charts_on_own_pages = true

    get janela.frame_path(janela_frames(:orders))

    assert_select ".janela-value-number", "$375.00"
  end
end
