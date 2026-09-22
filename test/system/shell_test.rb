require "application_system_test_case"

# The shell is the two-column shape shared by the gallery and the demo's own
# documentation: a sidebar flush to the window's left edge, a content column
# beside it, and the footer inside that column rather than full width below
# it (Tailwind's own docs are the model). One shell rather than two that look
# alike, so what holds it in place is tested once here, against every kind of
# page that uses it, rather than once per page.
class ShellTest < ApplicationSystemTestCase
  def shell_pages
    { "gallery" => gallery_path, "docs index" => docs_path, "a document" => doc_path("multi-tenancy"),
      "vitral" => vitral_path }
  end

  # A previous full-bleed pass checked only 1280 and 1600, both narrower than
  # the `.gallery-layout` max-width it had left in place, so it passed there
  # and still banded at 1900, the width actually used. Checked at four widths
  # this time, two either side of that old, since-removed cap, so a future
  # cap would fail here again before it ships.
  test "the shell stays flush to both window edges at any width" do
    [ 1280, 1600, 1920, 2560 ].each do |width|
      shell_pages.each do |name, path|
        Capybara.current_session.current_window.resize_to(width, 1200)
        # A plain Capybara visit rather than the base class's: that override
        # waits for every pane to finish loading, and resizing before the
        # load settles never lets it, the same reasoning responsive_test.rb
        # gives for a phone width. Grid layout is settled long before any of
        # that, and a documentation page has no pane to wait for at all.
        Capybara.current_session.visit(path)
        # Geometry is the stylesheet's answer, and the page is in the DOM
        # before the stylesheet is. Unstyled, the nav sits at 8px rather than
        # 0 and the content stops short of the edge, so losing this race fails
        # the assertion rather than passing it by accident (#52).
        wait_for_stylesheets

        # document.documentElement.clientWidth, not window.innerWidth: the
        # latter includes the vertical scrollbar this page always has (its
        # content is taller than 1200px at every width here), so it reads
        # about 15px wider than the viewport actually available to layout.
        nav_left, main_right, viewport_width = page.evaluate_script(<<~JS)
          [
            document.querySelector(".shell-nav").getBoundingClientRect().left,
            document.querySelector(".shell-main").getBoundingClientRect().right,
            document.documentElement.clientWidth,
          ]
        JS

        assert_equal 0, nav_left, "#{name}'s sidebar is not flush to the left edge at #{width}"
        assert_equal viewport_width, main_right, "#{name}'s content is not flush to the right edge at #{width}"
      end
    end
  ensure
    Capybara.current_session.current_window.resize_to(1400, 1400)
  end

  # The exemplar's sidebar shares the page's own background, with only a
  # hairline on its right telling it apart from the content beside it, flush
  # under the top bar rather than sitting a gap below it. The bare `<nav>`
  # element picks up the site nav's own glass fill and its bottom edge unless
  # `.shell-nav` says otherwise, which is what made it read as a panel
  # sitting on the page instead of sharing it (see the CSS for the story).
  test "the sidebar is plain white, hairlined from the content, and flush under the top bar" do
    shell_pages.each do |name, path|
      visit path

      background, background_image, border_bottom, border_right, site_nav_bottom, shell_nav_top = page.evaluate_script(<<~JS)
        (() => {
          const style = getComputedStyle(document.querySelector(".shell-nav"))
          return [
            style.backgroundColor,
            style.backgroundImage,
            style.borderBottomWidth,
            style.borderRightWidth,
            document.querySelector("body > nav").getBoundingClientRect().bottom,
            document.querySelector(".shell-nav").getBoundingClientRect().top,
          ]
        })()
      JS

      assert_equal "rgb(255, 255, 255)", background, "#{name}'s sidebar is not plain white"
      assert_equal "none", background_image, "#{name}'s sidebar carries a panel background of its own"
      assert_equal "0px", border_bottom, "#{name}'s sidebar carries a bottom edge of its own"
      assert_not_equal "0px", border_right, "#{name}'s sidebar carries no hairline against the content"
      assert_in_delta site_nav_bottom, shell_nav_top, 1, "#{name}'s sidebar does not sit flush under the top bar"
    end
  end

  # Believed false: a page either uses the shell or it does not, and the
  # layout can tell by controller name. /vitral is `pages#vitral`, in the same
  # controller as two pages that are not shell pages, so it got the layout's
  # footer as well as the shell's own and rendered two. Nothing caught it
  # because the footer carries an id, so every check that reached for
  # #site-footer found the first of the two and was satisfied.
  test "every page renders exactly one footer" do
    (shell_pages.merge("home" => root_path, "the name" => the_name_path)).each do |name, path|
      visit path

      assert_equal 1, page.evaluate_script("document.querySelectorAll('#site-footer').length"),
        "#{name} does not render exactly one footer"
    end
  end

  # Full width of the column on purpose, not the usual full width of the
  # window: the sidebar beside it runs the column's full height, which only
  # reads as one shell if the footer sits inside what the sidebar is running
  # alongside rather than spanning under it too.
  test "the footer sits inside the content column, not full width beneath it" do
    shell_pages.each do |name, path|
      visit path

      main_left, footer_left = page.evaluate_script(<<~JS)
        [
          document.querySelector(".shell-main").getBoundingClientRect().left,
          document.querySelector("#site-footer").getBoundingClientRect().left,
        ]
      JS

      assert_equal main_left, footer_left, "#{name}'s footer is not inside the content column"
    end
  end

  # The page a reader is on is marked in the Documentation group: current_page?
  # decides it server side, since each of these is a page of its own rather
  # than an in-page jump.
  test "the document you are reading is marked current in the sidebar" do
    visit doc_path("multi-tenancy")

    assert_selector ".shell-nav a.current", text: "Multi tenancy"
  end

  # Kept from before the shell was shared: the Reference group's links are
  # in-page jumps on the gallery, so which one is current is asked of the
  # browser via :target rather than marked by the server, and the browser
  # glides there with the smooth scroll `html` sets, landing clear of the
  # sticky top bar because each section carries its own scroll margin.
  #
  # Arrived at fresh, the way a reader following the Reference group from a
  # document actually gets there, rather than clicked from the gallery
  # itself: Turbo treats an anchor-only click on the page it is already
  # showing as a local scroll and never touches the address bar for it, so a
  # same-page click could never make this assertion true either before this
  # shell existed or after, and testing it that way would fail for a reason
  # this feature does not own.
  test "the gallery's renderer links still jump smoothly to their section" do
    Capybara.current_session.visit(gallery_path(anchor: "gallery-bar"))
    wait_for_stylesheets

    scroll_behavior = page.evaluate_script("getComputedStyle(document.documentElement).scrollBehavior")
    scroll_margin_top = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector("#gallery-bar")).scrollMarginTop
    JS
    assert_equal "smooth", scroll_behavior
    assert_not_equal "0px", scroll_margin_top

    assert_selector "#gallery-bar:target"
    assert_equal "rgb(40, 110, 205)", page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector('.shell-nav a[href$="#gallery-bar"]')).borderLeftColor
    JS
  end
end
