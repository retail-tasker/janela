require "application_system_test_case"

# ADR 045. The numbers on this page are rendered by the server before any
# JavaScript runs, so a right number proves nothing about the click. These
# click the drawn line and read the frame's filters back.
class TimeClickTest < ApplicationSystemTestCase
  test "clicking a day on the line filters the other panes to that day" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    click_point(0)

    assert_equal({ "placed_on_gteq" => "2026-09-01", "placed_on_lt" => "2026-09-02" }, frame_filters)
    within_visual("Revenue by Region") do
      assert_text "$100.00"
      assert_no_text "$225.00"
    end
  end

  # Measured before ADR 045 was written: with the range applied to its own
  # pane the line collapsed to one point. It must keep every day and mark the
  # one that is selected.
  test "the line keeps every day and marks the selected one" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    click_point(1)
    within_visual("Revenue by Region") { assert_no_text "$225.00" }

    assert_equal 4, line_value("chart.data.labels.length")
    assert_equal [ "2026-09-02" ], eventually([ "2026-09-02" ]) { line_value("chart.data.labels.filter((l, i) => c.selectedValue.includes(l))") }
  end

  test "clicking the selected day again clears it" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    click_point(0)
    within_visual("Revenue by Region") { assert_no_text "$225.00" }
    click_point(0)

    within_visual("Revenue by Region") { assert_text "$225.00" }
    assert_equal({}, frame_filters)
  end

  test "clicking another day replaces the range rather than adding to it, even with ctrl held" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    click_point(0)
    within_visual("Revenue by Region") { assert_no_text "$225.00" }
    click_point(2, ctrl: true)

    eventually({ "placed_on_gteq" => "2026-09-03", "placed_on_lt" => "2026-09-04" }) { frame_filters }
    assert_equal({ "placed_on_gteq" => "2026-09-03", "placed_on_lt" => "2026-09-04" }, frame_filters)
  end

  test "a day and a status intersect" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    click_point(0)
    within(:xpath, "//figure[figcaption[text()='Orders by Status']]") { click_on "paid" }

    expected = { "placed_on_gteq" => "2026-09-01", "placed_on_lt" => "2026-09-02", "status_in" => [ "paid" ] }
    assert_equal expected, eventually(expected) { frame_filters }
  end

  private
    def line_title
      "Revenue by Placed on per day"
    end

    def canvas_xpath
      %(//figure[figcaption[text()='#{line_title}']]/canvas)
    end

    def controller_js
      %(window.Stimulus.getControllerForElementAndIdentifier(document.evaluate("#{canvas_xpath}", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue, "janela--chart"))
    end

    def line_value(expression)
      assert_selector(:xpath, canvas_xpath)
      20.times do
        value = page.evaluate_script("(() => { const c = #{controller_js}; return c && c.chart ? c.#{expression} : null })()")
        return value unless value.nil?
        sleep 0.1
      end
      flunk "chart never initialised"
    end

    def click_point(index, ctrl: false)
      wait_for_frames
      canvas = find(:xpath, canvas_xpath)
      x, y = page.evaluate_script(<<~JS)
        (() => {
          const c = #{controller_js};
          const point = c.chart.getDatasetMeta(0).data[#{index}];
          const rect = c.element.getBoundingClientRect();
          return [Math.round(point.x - rect.width / 2), Math.round(point.y - rect.height / 2)];
        })()
      JS
      action = page.driver.browser.action
      action = action.key_down(:control) if ctrl
      action = action.move_to(canvas.native, x, y).click
      action = action.key_up(:control) if ctrl
      action.perform
    end

    def eventually(expected)
      20.times do
        actual = yield
        return actual if actual == expected

        sleep 0.1
      end
      yield
    end

    def frame_filters
      wait_for_frames
      JSON.parse(find("[data-controller='janela--frame']", match: :first)["data-janela--frame-filters-value"] || "{}")
    end

    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
