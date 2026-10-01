require "application_system_test_case"

class ChartTest < ApplicationSystemTestCase
  test "a bar pane renders a chart" do
    visit orders_path

    assert_selector(:xpath, canvas_xpath("Revenue by Status"))
    assert_equal 3, chart_value("chart.data.labels.length")
  end

  test "a time pane renders a line chart" do
    visit orders_path

    # The demo gives this line a height (ADR 047), which puts its canvas in a
    # box inside the figure, so it is found by descent and not as a child.
    assert_selector(:xpath, "//figure[figcaption[text()='Revenue by Placed on per month']]//canvas[@data-janela--chart-type-value='line']")
  end

  # #62: three literal rgba(54, 162, 235, ...) strings in chart_controller.js
  # drew Chart.js's own default blue no matter what a theme set. The demo
  # runs vitral, which now sets its own first series colour (#67), so a bar
  # disagreed with the very theme installed alongside it.
  test "a bar's colour comes from the theme's first series colour, not a hardcoded blue" do
    visit orders_path

    first_rgb = page.evaluate_script(<<~JS).scan(/\d+/).first(3)
      (() => {
        const probe = document.createElement("span")
        probe.style.color = getComputedStyle(document.documentElement).getPropertyValue("--janela-series-1")
        document.body.appendChild(probe)
        const resolved = getComputedStyle(probe).color
        probe.remove()
        return resolved
      })()
    JS
    bar_rgb = chart_value("chart.data.datasets[0].backgroundColor[0]").scan(/\d+/).first(3)

    assert_equal first_rgb, bar_rgb
  end

  # ADR 046: a bar used to be one colour and told its categories apart by
  # position alone. Believed while writing #30: that bars would keep the accent
  # and only rings needed a palette. The maintainer chose the palette for both.
  test "each bar takes its own colour from the palette" do
    visit orders_path

    colours = chart_value("chart.data.datasets[0].backgroundColor").map { |colour| colour.scan(/\d+/).first(3) }

    assert_equal 3, colours.uniq.size
  end

  # Vitral is the demo's theme, and it chooses the palette (ADR 026, #67): the
  # second bar is drawn in the theme's second colour, not Janela's neutral one.
  test "a bar takes its colour from the theme's series palette" do
    visit orders_path

    series_two = page.evaluate_script(<<~JS).scan(/\d+/).first(3)
      (() => {
        const probe = document.createElement("span")
        probe.style.color = getComputedStyle(document.documentElement).getPropertyValue("--janela-series-2")
        document.body.appendChild(probe)
        const resolved = getComputedStyle(probe).color
        probe.remove()
        return resolved
      })()
    JS
    drawn = chart_value("chart.data.datasets[0].backgroundColor[1]").scan(/\d+/).first(3)

    assert_equal %w[86 171 129], series_two, "the theme's sage, #56ab81"
    assert_equal series_two, drawn
  end

  test "clicking a bar re-scopes the other visuals but not itself" do
    visit orders_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    label = chart_value("chart.data.labels[0]")
    click_bar(0)

    assert_frame_filters({ "status_in" => [ label ] })
    within_visual("Revenue by Region") { assert_no_text "$225.00" }
    assert_equal 3, chart_value("chart.data.labels.length")
  end

  test "ctrl clicking a second bar adds it to the selection and both stay solid" do
    visit orders_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    first = chart_value("chart.data.labels[0]")
    second = chart_value("chart.data.labels[1]")
    click_bar(0)
    # Chart.js delivers a click a frame or more after the browser dispatches it,
    # so a second click issued at once can be heard first, and the first then
    # replaces it: measured under load, it ended on only the first bar (#66).
    assert_frame_filters({ "status_in" => [ first ] })
    ctrl_click_bar(1)

    assert_frame_filters({ "status_in" => [ first, second ].sort })
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

    # The canvas carries no visible or aria text of its own since ADR 042; its
    # title lives in the figcaption beside it, so that is what a test finds it
    # by, the same way `within_visual` already finds a table by its caption.
    def canvas_xpath(title)
      %(//figure[figcaption[text()='#{title}']]/canvas)
    end

    def ctrl_click_bar(index)
      # A click before this one replaces the pane on its way to the new
      # selection, and the canvas found here is detached the moment it lands:
      # the click then goes to a node that is no longer in the document and
      # Selenium raises a stale element reference. Waiting for the frame to
      # settle first is the same readiness the suite uses before any click,
      # rather than a longer wait hiding the race.
      wait_for_frames
      canvas = find(:xpath, canvas_xpath("Revenue by Status"))
      offset = bar_offset(index)
      page.driver.browser.action
        .key_down(:control)
        .move_to(canvas.native, *offset)
        .click
        .key_up(:control)
        .perform
    end

    def chart_controller_js(title: "Revenue by Status")
      %(window.Stimulus.getControllerForElementAndIdentifier(document.evaluate("#{canvas_xpath(title)}", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue, "janela--chart"))
    end

    def chart_value(expression, title: "Revenue by Status")
      assert_selector(:xpath, canvas_xpath(title))
      20.times do
        value = page.evaluate_script("(() => { const c = #{chart_controller_js(title: title)}; return c && c.chart ? c.#{expression} : null })()")
        return value unless value.nil?
        sleep 0.1
      end
      flunk "chart never initialised"
    end

    def click_bar(index)
      wait_for_frames
      canvas = find(:xpath, canvas_xpath("Revenue by Status"))
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


    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
