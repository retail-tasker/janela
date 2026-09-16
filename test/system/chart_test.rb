require "application_system_test_case"

class ChartTest < ApplicationSystemTestCase
  test "a bar pane renders a chart" do
    visit orders_path

    assert_selector "canvas.janela-chart[aria-label='Revenue by Status']"
    assert_equal 3, chart_value("chart.data.labels.length")
  end

  test "a time pane renders a line chart" do
    visit orders_path

    assert_selector "canvas.janela-chart[aria-label='Revenue by Placed on per month'][data-janela--chart-type-value=line]"
  end

  test "clicking a bar re-scopes the other visuals but not itself" do
    visit orders_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    label = chart_value("chart.data.labels[0]")
    click_bar(0)

    assert_equal({ "status_in" => [ label ] }, frame_filters)
    within_visual("Revenue by Region") { assert_no_text "$225.00" }
    assert_equal 3, chart_value("chart.data.labels.length")
  end

  test "ctrl clicking a second bar adds it to the selection and both stay solid" do
    visit orders_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    first = chart_value("chart.data.labels[0]")
    second = chart_value("chart.data.labels[1]")
    click_bar(0)
    ctrl_click_bar(1)

    assert_equal({ "status_in" => [ first, second ].sort }, frame_filters)
    # A bar that is not selected is drawn faded, so two solid bars is the
    # selection made visible (ADR 024). Turbo replaces the pane on its way to
    # that state, so this waits for it rather than reading the chart it is
    # about to throw away.
    assert_equal 2, eventually(2) { solid_bars }
  end

  private
    def solid_bars
      chart_value("chart.data.datasets[0].backgroundColor.filter((c) => c.endsWith('0.9)')).length")
    end

    def eventually(expected)
      20.times do
        actual = yield
        return actual if actual == expected

        sleep 0.1
      end
      yield
    end

    def ctrl_click_bar(index)
      canvas = find("canvas.janela-chart[aria-label='Revenue by Status']")
      offset = bar_offset(index)
      page.driver.browser.action
        .key_down(:control)
        .move_to(canvas.native, *offset)
        .click
        .key_up(:control)
        .perform
    end

    def chart_controller_js
      %(window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("canvas.janela-chart[aria-label='Revenue by Status']"), "janela--chart"))
    end

    def chart_value(expression)
      assert_selector "canvas.janela-chart[aria-label='Revenue by Status']"
      20.times do
        value = page.evaluate_script("(() => { const c = #{chart_controller_js}; return c && c.chart ? c.#{expression} : null })()")
        return value unless value.nil?
        sleep 0.1
      end
      flunk "chart never initialised"
    end

    def click_bar(index)
      canvas = find("canvas.janela-chart[aria-label='Revenue by Status']")
      page.driver.browser.action.move_to(canvas.native, *bar_offset(index)).click.perform
    end

    def bar_offset(index)
      page.evaluate_script(<<~JS)
        (() => {
          const c = #{chart_controller_js};
          const bar = c.chart.getDatasetMeta(0).data[#{index}];
          const rect = c.element.getBoundingClientRect();
          return [Math.round(bar.x - rect.width / 2), Math.round((bar.y + bar.base) / 2 - rect.height / 2)];
        })()
      JS
    end

    def frame_filters
      JSON.parse(find("[data-controller='janela--frame']")["data-janela--frame-filters-value"] || "{}")
    end

    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
