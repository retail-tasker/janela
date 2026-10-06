require "test_helper"

# ADR 054, #72. The server sends what a tick needs as one attribute and the
# chart controller does the drawing, so this reads only what the page asks for;
# test/system/chart_axis_test.rb reads what was drawn.
class ChartAxisTest < ActionDispatch::IntegrationTest
  test "a currency measure sends its prefix" do
    get janela.pane_path("orders", "revenue", "status", as: "bar")

    assert_equal({ "prefix" => "$", "suffix" => "", "ratio" => false }, tick_format)
  end

  test "a ratio says so, and sends no unit of its own because the controller supplies the percent sign" do
    get janela.pane_path("orders", "expedited_rate", "status", as: "bar")

    assert_equal({ "prefix" => "", "suffix" => "", "ratio" => true }, tick_format)
  end

  test "a count has nothing to add, so its ticks are what they always were" do
    get janela.pane_path("orders", "orders", "status", as: "bar")

    assert_equal({ "prefix" => "", "suffix" => "", "ratio" => false }, tick_format)
  end

  test "a line sends it as a bar does" do
    get janela.pane_path("orders", "revenue", "placed_on", as: "line")

    assert_equal "$", tick_format["prefix"]
  end

  private
    def tick_format
      JSON.parse(css_select("canvas").first["data-janela--chart-tick-format-value"])
    end
end
