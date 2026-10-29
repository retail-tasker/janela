require "application_system_test_case"

# ADR 063. A frame over two models: the orders bar is the click source, and
# the page views panes beside it either keep their numbers or are refused,
# depending on whether the row asked to ignore what it cannot apply.
class IgnoreUnknownFiltersTest < ApplicationSystemTestCase
  setup do
    PageView.record(controller: "pages", action: "home", path: "/")
    PageView.record(controller: "docs", action: "show", path: "/docs/theming")
    frame = janela_frames(:orders)
    frame.panes.create!(model: "page_views", measure: "views", title: "Views, kept", ignore_unknown_filters: true)
    frame.panes.create!(model: "page_views", measure: "views", title: "Views, refused")
  end

  test "a bar clicked on another model's pane leaves the pane that ignores unknown filters standing" do
    visit frame_path(janela_frames(:orders))
    assert_text "Views, kept"

    click_bar("Revenue by Status", 0)

    assert_frame_filters({ "status_in" => [ "paid" ] })
    within(:xpath, "//p[span[text()='Views, kept']]") { assert_text "2" }
    assert_text "That request is not allowed on this pane."
    assert_no_text "Views, refused"
  end

  private
    def canvas_xpath(title)
      %(//figure[figcaption[text()='#{title}']]/canvas)
    end

    def controller_js(title)
      %(window.Stimulus.getControllerForElementAndIdentifier(document.evaluate("#{canvas_xpath(title)}", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue, "janela--chart"))
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
end
