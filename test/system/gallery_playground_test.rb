require "application_system_test_case"

# The gallery's controls reach every option a pane takes, not only the three it
# started with, so a reader can try a chart's height, its bar labels, a single
# value's prominence and a table's companion columns against live data and copy
# the declaration that produced it. Built from Janela.heights,
# Janela.prominences and Janela.max_companions, never from a constant reached
# into (ADR 027).
#
# Believed while building it: that every control belongs beside every pane.
# Height and bar labels do nothing to a table or a ring, and companions do
# nothing to a chart, so each is shown only while the renderer chosen is one it
# changes; a dead control would be a lie about what the pane can do (#40).
class GalleryPlaygroundTest < ApplicationSystemTestCase
  BAR = "#gallery-bar-orders-entry".freeze

  test "a chart's height is a control, and the pane is drawn in a box of that step" do
    visit gallery_path

    within(BAR) do
      select "Short", from: "Height"

      assert_selector ".janela-chart-box.janela-h-2"
      assert_text "as: :bar, height: 2"
      assert_includes find("turbo-frame", visible: :all)["data-janela-asked"], "height=2"
    end
  end

  test "bar labels are a checkbox, and the pane asks for them" do
    visit gallery_path

    within(BAR) do
      assert_no_selector "canvas[data-janela--chart-value-labels-value]"

      check "Show each bar's value"

      assert_selector "canvas[data-janela--chart-value-labels-value=true]"
      assert_text "value_labels: true"
    end
  end

  test "a single value's prominence is a control" do
    visit gallery_path

    within("#gallery-table-orders-entry") do
      select "Hero", from: "Prominence"

      assert_selector "p.janela-value.janela-prominence-3"
      assert_text "janela_pane Order, :revenue, prominence: 3"
    end
  end

  test "companion columns appear for a table, and a table then carries them" do
    visit gallery_path

    within(BAR) do
      select "Table", from: "Renderer"
      check "Orders"

      assert_selector "table th", text: "Orders"
      assert_text "companions: [:orders]"
    end
  end

  # The pane refuses a fourth companion with a 400, so the control stops
  # offering one rather than letting a reader draw an error.
  test "a fourth companion cannot be chosen" do
    visit gallery_path

    within(BAR) do
      select "Table", from: "Renderer"
      %w[Orders Average\ order Expedited\ rate].each { |name| check name }

      assert_selector "input[type=checkbox][name='companions[]']:disabled:not(:checked)", minimum: 1
      assert_selector "input[type=checkbox][name='companions[]']:checked", count: 3
    end
  end

  test "each control is shown only while the renderer chosen is one it changes" do
    visit gallery_path

    within(BAR) do
      assert_field "Height"
      assert_field "Show each bar's value"
      assert_no_field "Orders"

      select "Line chart", from: "Renderer"
      assert_field "Height"
      assert_no_field "Show each bar's value"

      select "Doughnut chart", from: "Renderer"
      assert_no_field "Height"
      assert_no_field "Show each bar's value"
      assert_no_field "Orders"

      select "Table", from: "Renderer"
      assert_no_field "Height"
      assert_field "Orders"
    end
  end

  # A declaration with options the renderer ignores would be code that reads as
  # if it did something, so it carries only what applies to what is drawn.
  test "the declaration drops an option once the renderer ignores it" do
    visit gallery_path

    within(BAR) do
      check "Show each bar's value"
      assert_text "value_labels: true"

      select "Doughnut chart", from: "Renderer"

      assert_text "as: :doughnut"
      assert_no_text "value_labels"
    end
  end

  # #43: reconfiguring a pane while the frame is filtered keeps the filter. The
  # new controls go through the same repoint, so they inherit it.
  # The fixtures are $375 of revenue in one month, $300 of it paid, so a line
  # that has lost the filter reads $375 whatever its height is.
  test "a new control keeps the frame's filter, as the others do" do
    visit gallery_path

    click_bar(0) # paid, the largest status and so the leftmost bar
    assert_selector "#gallery-line-orders-entry canvas[data-janela--chart-values-value='[300.0]']"

    within("#gallery-line-orders-entry") do
      select "Short", from: "Height"

      assert_selector ".janela-chart-box.janela-h-2"
      assert_selector "canvas[data-janela--chart-values-value='[300.0]']"
    end
  end

  private
    def click_bar(index)
      wait_for_frames
      canvas = find("#{BAR} canvas.janela-chart")
      offset = page.evaluate_script(<<~JS)
        (() => {
          const controller = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("#{BAR} canvas.janela-chart"), "janela--chart")
          const bar = controller.chart.getDatasetMeta(0).data[#{index}]
          const rect = controller.element.getBoundingClientRect()
          return [ Math.round(bar.x - rect.width / 2), Math.round((bar.y + bar.base) / 2 - rect.height / 2) ]
        })()
      JS

      page.driver.browser.action.move_to(canvas.native, *offset).click.perform
    end
end
