require "application_system_test_case"

# ADR 045. The numbers on this page are rendered by the server before any
# JavaScript runs, so a right number proves nothing about the click. These
# click the drawn line and read the frame's filters back.
#
# The front page's line is weekly. The fixtures all fall in one week, so a
# second order in the next gives the line two points to tell apart.
class TimeClickTest < ApplicationSystemTestCase
  setup do
    Order.create!(customer: Customer.find_by!(name: "Globex"), status: "paid", amount: 40, placed_on: Date.new(2026, 9, 10))
  end

  test "clicking a week on the line filters the other panes to that week" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$265.00" }

    click_point(1)

    assert_equal({ "placed_on_gteq" => "2026-09-07", "placed_on_lt" => "2026-09-14" }, frame_filters)
    within_visual("Revenue by Region") do
      assert_text "$40.00"
      assert_no_text "$265.00"
    end
  end

  # Measured before ADR 045 was written: with the range applied to its own
  # pane the line collapsed to one point. It must keep every week and mark the
  # one that is selected.
  test "the line keeps every week and marks the selected one" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$265.00" }

    click_point(1)
    within_visual("Revenue by Region") { assert_no_text "$265.00" }

    assert_equal 2, line_value("chart.data.labels.length")
    assert_equal [ "2026-09-07" ], eventually([ "2026-09-07" ]) { line_value("chart.data.labels.filter((l) => c.selectedValue.includes(l))") }
  end

  test "clicking the selected week again clears it" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$265.00" }

    click_point(1)
    within_visual("Revenue by Region") { assert_no_text "$265.00" }
    click_point(1)

    within_visual("Revenue by Region") { assert_text "$265.00" }
    assert_equal({}, frame_filters)
  end

  test "clicking another week replaces the range rather than adding to it, even with ctrl held" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$265.00" }

    click_point(1)
    within_visual("Revenue by Region") { assert_no_text "$265.00" }
    click_point(0, ctrl: true)

    expected = { "placed_on_gteq" => "2026-08-31", "placed_on_lt" => "2026-09-07" }
    assert_equal expected, eventually(expected) { frame_filters }
  end

  test "a week and a status intersect" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$265.00" }

    click_point(1)
    within(:xpath, "//figure[figcaption[text()='Orders by Status']]") { click_on "paid" }

    expected = { "placed_on_gteq" => "2026-09-07", "placed_on_lt" => "2026-09-14", "status_in" => [ "paid" ] }
    assert_equal expected, eventually(expected) { frame_filters }
  end

  private
    def canvas_xpath
      %(//figure[figcaption[text()='Revenue by Placed on per week']]/canvas)
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
