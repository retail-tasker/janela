require "application_system_test_case"

# ADR 054, #72. Believed (ADR 020): an axis is a scale and not a label, so it
# could be left as Chart.js draws it. A reader reads the axis as labels: a
# ratio drew 0, 0.2 ... 1 beside tooltips reading 50.0%, and revenue drew
# 50,000 beside $469,097.85. These read the tick labels Chart.js drew, not the
# attribute that asked for them (ADR 035).
class ChartAxisTest < ApplicationSystemTestCase
  test "a currency measure's ticks carry its prefix" do
    visit orders_path

    ticks = ticks_of("Revenue by Status")

    assert_operator ticks.size, :>, 1
    assert ticks.all? { |tick| tick.start_with?("$") }, "ticks were #{ticks.inspect}"
  end

  test "a line's ticks carry the prefix too" do
    visit orders_path

    ticks = ticks_of("Revenue by Placed on per month")

    assert ticks.all? { |tick| tick.start_with?("$") }, "ticks were #{ticks.inspect}"
  end

  test "a ratio's ticks read as percentages, not as the fraction" do
    visit orders_path

    ticks = ticks_of("Expedited rate by Channel")

    assert ticks.all? { |tick| tick.end_with?("%") }, "ticks were #{ticks.inspect}"
    assert_equal "0%", ticks.first
    assert_equal "100%", ticks.last
  end

  private
    def ticks_of(title)
      wait_for_frames
      value = nil
      30.times do
        value = page.evaluate_script(<<~JS)
          (() => {
            const canvas = document.evaluate("//figure[figcaption[text()='#{title}']]//canvas", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
            const chart = canvas && Stimulus.getControllerForElementAndIdentifier(canvas, "janela--chart")?.chart
            return chart ? chart.scales.y.ticks.map((tick) => tick.label) : null
          })()
        JS
        return value if value
        sleep 0.1
      end
      flunk "chart #{title.inspect} never drew"
    end
end
