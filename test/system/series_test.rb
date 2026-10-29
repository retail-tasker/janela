require "application_system_test_case"

# ADR 062. The numbers a combo pane carries are rendered by the server, so a
# right table proves nothing about the chart: these read the chart Chart.js
# built, its datasets and its two axes, and then click another pane and read
# the chart again.
#
# The fixtures are four September orders, two of them shipped. One October
# order, placed and shipped, gives every series a second month to move in.
class SeriesTest < ApplicationSystemTestCase
  COMBO = "Orders to date by Placed on per month".freeze
  # The table a surface with no chart runtime shows instead is read by the
  # unit suite from the pane URL; here the chart is the thing under test.
  SERIES = [ { measure: "orders", by: "shipped_on", cumulative: "1", title: "Orders shipped to date" },
             { measure: "orders", as: "bar", axis: "right", title: "Orders per month" } ].freeze

  setup do
    Order.create!(customer: Customer.find_by!(name: "Globex"), status: "paid", amount: 40, placed_on: Date.new(2026, 10, 5), shipped_on: Date.new(2026, 10, 7))
  end

  test "a hand written pane draws three datasets on two titled axes, and changes when a value on another pane is clicked" do
    visit orders_path

    assert_equal 3, combo("chart.data.datasets.length")
    assert_equal [ "line", "line", "bar" ], combo("chart.data.datasets.map((d) => d.type)")
    assert_equal [ "y", "y", "y1" ], combo("chart.data.datasets.map((d) => d.yAxisID)")
    assert_equal "Orders to date, Orders shipped to date", combo("chart.options.scales.y.title.text")
    assert_equal "Orders per month", combo("chart.options.scales.y1.title.text")
    assert_equal [ 4, 5 ], combo("chart.data.datasets[0].data")
    assert_equal [ 2, 3 ], combo("chart.data.datasets[1].data")
    assert_equal [ 4, 1 ], combo("chart.data.datasets[2].data")
    assert combo("chart.legend.legendItems.length") == 3, "a chart with series shows its legend"

    within(:xpath, "//table[caption[text()='Orders by Region']]") { click_on "EU" }

    assert_frame_filters({ "customer_region_in" => [ "EU" ] })
    assert_equal [ 2, 3 ], eventually([ 2, 3 ]) { combo("chart.data.datasets[0].data") }
    assert_equal [ 1, 2 ], combo("chart.data.datasets[1].data")
    assert_equal [ 2, 1 ], combo("chart.data.datasets[2].data")
  end

  # The stored frame's bar pane is the click source here, so the chart that
  # changes is a row and the click is on a canvas.
  test "a stored pane draws the same, and a bar clicked on another pane narrows every series" do
    frame = janela_frames(:orders)
    frame.panes.create!(model: "orders", measure: "orders", dimension: "placed_on", renderer: "line", granularity: "month",
                        cumulative: true, span: 3, series: SERIES)

    visit frame_path(frame)
    assert_equal [ 4, 5 ], combo("chart.data.datasets[0].data")
    assert_equal [ 2, 3 ], combo("chart.data.datasets[1].data")

    click_bar("Revenue by Status", 0)

    assert_frame_filters({ "status_in" => [ "paid" ] })
    assert_equal [ 2, 3 ], eventually([ 2, 3 ]) { combo("chart.data.datasets[0].data") }
    assert_equal [ 2, 3 ], combo("chart.data.datasets[1].data")
    assert_equal [ 2, 1 ], combo("chart.data.datasets[2].data")
  end

  # Review findings on #91. The right axis speaks the format of the series on
  # it, not the pane's own, so it agrees with the tooltip; and a dataset the
  # reader has hidden draws no value label.
  test "the right axis's ticks carry the prefix of the series on it, and the left axis's do not" do
    frame = janela_frames(:orders)
    frame.panes.create!(model: "orders", measure: "orders", dimension: "placed_on", renderer: "line", granularity: "month", span: 3,
                        series: [ { measure: "revenue", as: "bar", axis: "right" } ])

    visit frame_path(frame)

    left = axis_ticks("Orders by Placed on per month", "y")
    right = axis_ticks("Orders by Placed on per month", "y1")
    assert right.any? && right.all? { |tick| tick.start_with?("$") }, "right ticks were #{right.inspect}"
    assert left.any? && left.none? { |tick| tick.include?("$") }, "left ticks were #{left.inspect}"
  end

  test "a dataset hidden from the legend draws no value label" do
    frame = janela_frames(:orders)
    frame.panes.create!(model: "orders", measure: "orders", dimension: "placed_on", renderer: "line", granularity: "month", span: 3,
                        value_labels: true, series: [ { measure: "revenue", axis: "right" } ])

    visit frame_path(frame)
    title = "Orders by Placed on per month"

    shown = drawn_labels(title, hide: nil)
    assert_includes shown, "$40.00"
    hidden = drawn_labels(title, hide: 1)
    assert_not_includes hidden, "$40.00"
    assert_includes hidden, "1"
  end

  private
    def canvas_xpath(title)
      %(//figure[figcaption[text()='#{title}']]/canvas)
    end

    def controller_js(title)
      %(window.Stimulus.getControllerForElementAndIdentifier(document.evaluate("#{canvas_xpath(title)}", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue, "janela--chart"))
    end

    def combo(expression)
      assert_selector(:xpath, canvas_xpath(COMBO))
      20.times do
        value = page.evaluate_script("(() => { const c = #{controller_js(COMBO)}; return c && c.chart ? c.#{expression} : null })()")
        return value unless value.nil?
        sleep 0.1
      end
      flunk "chart never initialised"
    end

    def click_bar(title, index)
      wait_for_frames
      canvas = find(:xpath, canvas_xpath(title))
      x, y = page.evaluate_script(<<~JS)
        (() => {
          const c = #{controller_js(title)};
          const bar = c.chart.getDatasetMeta(0).data[#{index}];
          const rect = c.element.getBoundingClientRect();
          return [Math.round(bar.x - rect.width / 2), Math.round((bar.y + bar.base) / 2 - rect.height / 2)];
        })()
      JS
      page.driver.browser.action.move_to(canvas.native, x, y).click.perform
    end

    def axis_ticks(title, scale)
      wait_for_frames
      page.evaluate_script(<<~JS)
        (() => {
          const canvas = document.evaluate("#{canvas_xpath(title)}", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
          const chart = Stimulus.getControllerForElementAndIdentifier(canvas, "janela--chart").chart
          return chart.scales["#{scale}"].ticks.map((tick) => tick.label)
        })()
      JS
    end

    def drawn_labels(title, hide:)
      wait_for_frames
      page.evaluate_script(<<~JS)
        (() => {
          const canvas = document.evaluate("#{canvas_xpath(title)}", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
          const controller = Stimulus.getControllerForElementAndIdentifier(canvas, "janela--chart")
          const chart = controller.chart
          chart.setDatasetVisibility(1, #{hide ? 'false' : 'true'})
          const calls = []
          const original = chart.ctx.fillText
          chart.ctx.fillText = function (text) { calls.push(text); return original.apply(this, arguments) }
          chart.update()
          chart.ctx.fillText = original
          return calls
        })()
      JS
    end

    def eventually(expected)
      20.times do
        actual = yield
        return actual if actual == expected

        sleep 0.1
      end
      yield
    end
end
