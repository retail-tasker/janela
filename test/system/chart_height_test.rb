require "application_system_test_case"

# ADR 047. The markup carrying a class proves nothing about the chart: a chart
# built with the aspect ratio on inside a box of fixed height is drawn at 2:1
# and the box is merely taller around it, which is how min-height failed when
# measured. These read the size Chart.js actually drew.
class ChartHeightTest < ApplicationSystemTestCase
  test "a chart with a height is drawn at exactly that height" do
    visit orders_path

    css, chart, width, room = eventually { drawn("Revenue by Placed on per month") }
    assert_equal [ 224, 224 ], [ css, chart ]
    # Believed: the height was the whole of it. With the aspect ratio still on,
    # Chart.js keeps the box's height and narrows the chart to hold 2:1, so a
    # test of the height alone passes on a chart half as wide as its pane.
    assert_in_delta room, width, 2
  end

  test "a chart with no height is drawn as it always was: two to one of its width, under the cap" do
    visit orders_path

    css, chart, width, _room = eventually { drawn("Revenue by Status") }
    assert_equal css, chart
    assert_in_delta width / 2.0, css, 2
  end

  test "the box is what sets the height: a narrower window keeps it" do
    visit orders_path
    eventually { drawn("Revenue by Placed on per month") }

    page.driver.browser.manage.window.resize_to(700, 1000)
    css, chart, width, room = settled { drawn("Revenue by Placed on per month") }
    assert_equal [ 224, 224 ], [ css, chart ]
    assert_in_delta room, width, 2
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  private
    def drawn(title)
      wait_for_frames
      page.evaluate_script(<<~JS)
        (() => {
          const canvas = document.evaluate("//figure[figcaption[text()='#{title}']]//canvas", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue
          const chart = canvas && Stimulus.getControllerForElementAndIdentifier(canvas, "janela--chart")?.chart
          return chart ? [Math.round(canvas.getBoundingClientRect().height), Math.round(chart.height), Math.round(chart.width), Math.round(canvas.parentElement.clientWidth)] : null
        })()
      JS
    end

    # A chart redraws after its box changes size, so the first reading after a
    # resize is the old one. Wait for the chart to fill the box it is in, and
    # let the assertion report it if it never does.
    def settled
      value = nil
      30.times do
        value = yield
        return value if value && (value[3] - value[2]).abs <= 2
        sleep 0.1
      end
      value
    end

    def eventually
      value = nil
      30.times do
        value = yield
        return value if value
        sleep 0.1
      end
      flunk "chart never drew"
    end
end
