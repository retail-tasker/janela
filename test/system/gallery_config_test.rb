require "application_system_test_case"

# #40: a control beside each gallery pane that rewrites what it draws without
# a page load. Investigating it first showed that rewriting the pane's own
# src and asking Turbo to reload it did not work: Query.turbo_frame_id baked
# the renderer, granularity and limit into the id, so a response for a
# changed selection never carried the id the pane already had, and Turbo had
# nothing to reconcile it against. That is #42, decided in ADR 029: the
# pane is named (`id:`) so its frame never moves, and the response answers to
# whatever frame asked for it. The control can now navigate the frame
# directly, the same way any other link or control would.
class GalleryConfigTest < ApplicationSystemTestCase
  BAR = "#gallery-bar canvas.janela-chart".freeze

  # The fixtures give every dimension three values at most, fewer than any
  # offered limit, so a limit here can never visibly trim a row: this proves
  # the pane went through a genuine round trip for the value chosen, by the
  # limit actually reaching the request Turbo made, rather than a control
  # that changes nothing at all. The frame's own id stays exactly as the
  # page named it throughout, which is the fix (#42, ADR 029): it no longer
  # has to move for Turbo to reconcile the response into it.
  test "changing the limit actually asks for a different query" do
    visit gallery_path

    within("#gallery-bar") do
      named_id = find("turbo-frame", visible: :all)["id"]

      select "5", from: "Rows"

      assert_selector "turbo-frame##{named_id}[complete]", visible: :all
      frame = find("turbo-frame##{named_id}", visible: :all)
      assert_includes frame["data-janela-asked"], "limit=5"
    end
  end

  test "changing the renderer actually redraws the pane as the new chart type" do
    visit gallery_path

    within("#gallery-bar") do
      assert_selector "canvas[data-janela--chart-type-value=bar]"

      select "Line chart", from: "Renderer"

      assert_selector "canvas[data-janela--chart-type-value=line]"
      assert_no_selector "canvas[data-janela--chart-type-value=bar]"
    end
  end

  test "changing the granularity actually redraws the pane with different buckets" do
    visit gallery_path

    within("#gallery-line") do
      before = find("canvas")["data-janela--chart-labels-value"]

      select "Year", from: "Granularity"

      assert_no_selector "canvas[data-janela--chart-labels-value='#{before}']"
    end
  end

  test "the declaration updates to match what is chosen, so it stays copyable" do
    visit gallery_path

    within("#gallery-bar") do
      assert_text "janela_pane Order, :revenue, by: :status"
      assert_no_text "as: :line"

      select "Line chart", from: "Renderer"

      assert_text "janela_pane Order, :revenue, by: :status, as: :line"
    end
  end

  test "a single-value pane offers no configuration, since none of the three parameters change it" do
    visit gallery_path

    within("#gallery-table") do
      assert_no_selector "select"
    end
  end

  # #43: the control rebuilt the pane's URL from the base the frame controller
  # rebuilds from, which carries no filters, and never put the frame's current
  # ones back on. The gallery is one janela_frame, so its panes cross-filter:
  # reconfiguring a pane while a filter was active refetched that one pane
  # unfiltered while every pane beside it stayed filtered, and nothing on the
  # page said so. It was believed a control could build a pane's URL itself as
  # long as it kept the frame controller's records in step; only the frame
  # controller knows what the frame is filtered to, so it cannot (ADR 030).
  #
  # The numbers are the point rather than the round trip. The fixtures are
  # $375 of revenue in one month, $300 of it paid, so a line pane that has
  # lost the filter reads $375 whatever granularity it is bucketed by.
  test "reconfiguring a pane while a filter is active keeps the filter" do
    visit gallery_path

    click_bar(0) # paid, the largest status and so the leftmost bar
    assert_selector "#gallery-line canvas[data-janela--chart-values-value='[300.0]']"

    within("#gallery-line") do
      by_month = find("canvas")["data-janela--chart-labels-value"]

      select "Year", from: "Granularity"

      assert_no_selector "canvas[data-janela--chart-labels-value='#{by_month}']"
      assert_selector "canvas[data-janela--chart-values-value='[300.0]']"
    end
  end

  private
    # A bar is drawn on a canvas, so clicking one means asking Chart.js where
    # it put it, the same way ChartTest does on the dashboard.
    def click_bar(index)
      wait_for_frames
      canvas = find(BAR)
      offset = page.evaluate_script(<<~JS)
        (() => {
          const controller = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("#{BAR}"), "janela--chart")
          const bar = controller.chart.getDatasetMeta(0).data[#{index}]
          const rect = controller.element.getBoundingClientRect()
          return [ Math.round(bar.x - rect.width / 2), Math.round((bar.y + bar.base) / 2 - rect.height / 2) ]
        })()
      JS

      page.driver.browser.action.move_to(canvas.native, *offset).click.perform
    end
end
