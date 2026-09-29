require "application_system_test_case"

# ADR 046. The ring is server drawn, so the numbers being right proves nothing
# about the click: these drive the real Stimulus action from a slice and from a
# legend button and read the frame's filters back.
class RingTest < ApplicationSystemTestCase
  test "a doughnut on the front page is drawn, with a legend of buttons" do
    visit root_path

    within(:xpath, ring_xpath) do
      assert_selector "svg.janela-ring-svg path.janela-ring-slice", count: 3
      assert_selector "table.janela-legend button", count: 3
    end
  end

  test "clicking a legend button re-scopes the other panes but not the ring" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    within(:xpath, ring_xpath) { click_on "paid" }

    assert_equal({ "status_in" => [ "paid" ] }, frame_filters)
    within_visual("Revenue by Region") { assert_no_text "$225.00" }
    within(:xpath, ring_xpath) do
      assert_selector "path.janela-ring-slice", count: 3
      assert_selector "path.janela-ring-slice.janela-dim", count: 2
      assert_selector "button[aria-pressed=true]", text: "paid"
    end
  end

  test "clicking a slice does what its legend button does" do
    visit root_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    click_first_slice

    assert_equal 1, frame_filters.fetch("status_in").size
    within_visual("Revenue by Region") { assert_no_text "$225.00" }
  end

  private
    # A slice's own centre is often in the hole or another slice, so an element
    # click misses it the way it would miss a person's finger. Aim at the
    # middle of the slice's band instead: halfway round its arc, halfway
    # between the hole and the rim (ADR 046). The first slice's share is read
    # from the legend, which is what the reader sees, rather than assumed.
    def click_first_slice
      wait_for_frames
      svg = find("figure.janela-ring svg.janela-ring-svg", match: :first)
      x, y = page.evaluate_script(<<~JS)
        (() => {
          const figure = document.querySelector("figure.janela-ring");
          const values = [...figure.querySelectorAll("table.janela-legend td:last-child")].map((td) => parseFloat(td.textContent.replace(/[^0-9.]/g, "")));
          const turns = values[0] / values.reduce((a, b) => a + b, 0) / 2;
          const angle = turns * 2 * Math.PI - Math.PI / 2;
          const scale = figure.querySelector("svg").getBoundingClientRect().width / 100;
          return [Math.round(Math.cos(angle) * 37.5 * scale), Math.round(Math.sin(angle) * 37.5 * scale)];
        })()
      JS
      page.driver.browser.action.move_to(svg.native, x, y).click.perform
    end

    def ring_xpath
      %(//figure[figcaption[text()='Orders by Status']])
    end

    def frame_filters
      wait_for_frames
      JSON.parse(find("[data-controller='janela--frame']", match: :first)["data-janela--frame-filters-value"] || "{}")
    end

    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
