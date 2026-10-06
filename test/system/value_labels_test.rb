require "application_system_test_case"

# ADR 054, #76. A canvas has no text to read, so what was drawn is read by
# recording the calls the chart makes to fillText while it redraws, and
# comparing them with where the bars are. The attribute that asked for labels
# proves only that a label was asked for.
class ValueLabelsTest < ApplicationSystemTestCase
  RATE = "Expedited rate by Channel".freeze

  test "each bar's value is drawn as the measure formats it, centred above the bar" do
    visit orders_path

    drawn = redraw(RATE)

    assert_equal drawn["formatted"], drawn["labels"].map { |label| label["text"] }
    drawn["labels"].zip(drawn["bars"]).each do |label, bar|
      assert_in_delta bar["x"], label["x"], 1
      assert_operator label["y"], :<, bar["y"], "a label is above the end of its bar"
    end
    # Believed while measuring #76: the tallest bar touches the top of the plot
    # and a label above it is clipped. The scale's grace is what leaves room.
    assert_operator drawn["labels"].map { |label| label["y"] }.min - 12, :>=, 0
    # The strings are the measure's own, 100.0%, and not the axis's 100%.
    assert_includes drawn["formatted"], "100.0%"
  end

  test "a bar chart that did not ask is drawn without any" do
    visit orders_path

    drawn = redraw("Revenue by Status")

    assert_empty drawn["labels"]
  end

  # Hiding only the labels that collide would label some bars and not others
  # for a reason a reader cannot see, so it is all of them or none (ADR 054).
  test "a chart too dense for its labels draws none rather than some" do
    visit orders_path

    drawn = redraw(RATE, data: Array.new(40) { |i| 0.01 * (i + 1) }, labels: Array.new(40) { |i| "c#{i}" }, formatted: Array.new(40) { |i| format("%.1f%%", i + 1) })

    assert_empty drawn["labels"]
  end

  test "a negative bar's label is below its end, where the bar is not" do
    visit orders_path

    drawn = redraw(RATE, data: [ 5, -3 ], formatted: [ "5", "-3" ], labels: [ "a", "b" ])
    above, below = drawn["labels"].zip(drawn["bars"])

    assert_operator above[0]["y"], :<, above[1]["y"]
    assert_operator below[0]["y"], :>, below[1]["y"]
  end

  private
    # Redraws the chart with fillText recorded, optionally with other data, and
    # returns the labels drawn (the strings the measure formatted, and nothing
    # else on the canvas) beside the bars they belong to.
    def redraw(title, data: nil, formatted: nil, labels: nil)
      wait_for_frames
      page.evaluate_script(<<~JS)
        (() => {
          const canvas = document.evaluate("//figure[figcaption[text()='#{title}']]//canvas", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
          const controller = Stimulus.getControllerForElementAndIdentifier(canvas, "janela--chart")
          const chart = controller.chart
          const data = #{data.to_json}, formatted = #{formatted.to_json}, labels = #{labels.to_json}
          if (labels) chart.data.labels = labels
          if (data) chart.data.datasets[0].data = data
          if (formatted) controller.formattedValue = formatted

          const calls = []
          const original = chart.ctx.fillText
          chart.ctx.fillText = function (text, x, y) { calls.push({ text, x, y }); return original.apply(this, arguments) }
          chart.update()
          chart.ctx.fillText = original

          const strings = controller.formattedValue
          return {
            formatted: strings,
            labels: calls.filter((call) => strings.includes(call.text)),
            bars: chart.getDatasetMeta(0).data.map((bar) => ({ x: bar.x, y: bar.y }))
          }
        })()
      JS
    end
end
