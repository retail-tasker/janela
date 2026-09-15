require "application_system_test_case"

class ChartTest < ApplicationSystemTestCase
  test "a bar pane renders a chart" do
    visit root_path

    assert_selector "canvas.janela-chart[aria-label='Revenue by Status']"
    assert_equal 3, chart_value("chart.data.labels.length")
  end

  test "a time pane renders a line chart" do
    visit root_path

    assert_selector "canvas.janela-chart[aria-label='Revenue by Placed on per month'][data-janela--chart-type-value=line]"
  end

  test "clicking a bar re-scopes the other visuals but not itself" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    label = chart_value("chart.data.labels[0]")
    click_bar(0)

    assert_equal({ "status_eq" => label }, frame_filters)
    within_visual("Revenue by Region") { assert_no_text "$225.00" }
    assert_equal 3, chart_value("chart.data.labels.length")
  end

  private
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
      offset = page.evaluate_script(<<~JS)
        (() => {
          const c = #{chart_controller_js};
          const bar = c.chart.getDatasetMeta(0).data[#{index}];
          const rect = c.element.getBoundingClientRect();
          return [Math.round(bar.x - rect.width / 2), Math.round((bar.y + bar.base) / 2 - rect.height / 2)];
        })()
      JS
      page.driver.browser.action.move_to(canvas.native, *offset).click.perform
    end

    def frame_filters
      JSON.parse(find("[data-controller='janela--frame']")["data-janela--frame-filters-value"] || "{}")
    end

    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
