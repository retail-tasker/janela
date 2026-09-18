require "application_system_test_case"

# ADR 018 keeps the engine's own pages chart free. The gallery is a host page
# built with janela_pane like any other, so it is exactly where a chart pane
# is expected to draw a chart rather than degrade to its table (#39).
class GalleryTest < ApplicationSystemTestCase
  # A previous full-bleed pass checked only 1280 and 1600, both narrower than
  # the `.gallery-layout` max-width it had left in place, so it passed there
  # and still banded at 1900, the width actually used. Checked at four widths
  # this time, two either side of that old, since-removed cap, so a future
  # cap would fail here again before it ships.
  test "the shell stays flush to both window edges at any width" do
    [ 1280, 1600, 1920, 2560 ].each do |width|
      Capybara.current_session.current_window.resize_to(width, 1200)
      # A plain Capybara visit rather than the base class's: that override
      # waits for every pane to finish loading, and resizing before the load
      # settles never lets it, the same reasoning responsive_test.rb gives
      # for a phone width. Grid layout is settled long before any of that.
      Capybara.current_session.visit(gallery_path)

      # document.documentElement.clientWidth, not window.innerWidth: the
      # latter includes the vertical scrollbar this page always has (its
      # content is taller than 1200px at every width here), so it reads
      # about 15px wider than the viewport actually available to layout.
      nav_left, main_right, viewport_width = page.evaluate_script(<<~JS)
        [
          document.querySelector(".gallery-nav").getBoundingClientRect().left,
          document.querySelector(".gallery-main").getBoundingClientRect().right,
          document.documentElement.clientWidth,
        ]
      JS

      assert_equal 0, nav_left, "sidebar is not flush to the left edge at #{width}"
      assert_equal viewport_width, main_right, "content is not flush to the right edge at #{width}"
    end
  ensure
    Capybara.current_session.current_window.resize_to(1400, 1400)
  end

  # The exemplar's sidebar shares the page's own background, with only a
  # hairline on its right telling it apart from the content beside it. The
  # bare `<nav>` element picks up the site nav's own glass fill and its
  # bottom edge unless `.gallery-nav` says otherwise, which is what made it
  # read as a panel sitting on the page instead.
  test "the sidebar carries no panel background or bottom edge of its own" do
    visit gallery_path

    background, border_bottom = page.evaluate_script(<<~JS)
      (() => {
        const style = getComputedStyle(document.querySelector(".gallery-nav"))
        return [ style.backgroundImage, style.borderBottomWidth ]
      })()
    JS

    assert_equal "none", background
    assert_equal "0px", border_bottom
  end

  test "the bar and line renderers actually draw charts, not tables, on this host page" do
    visit gallery_path

    assert_selector "canvas.janela-chart[data-janela--chart-type-value=bar]"
    assert_selector "canvas.janela-chart[data-janela--chart-type-value=line]"
  end
end
