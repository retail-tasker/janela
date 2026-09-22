require "application_system_test_case"

# The demo's shell has to fit a phone. Nothing here is Janela's concern (the
# gem ships no layout), but the demo stands in for every host and a host that
# copies this nav is entitled to expect it does not scroll sideways (see the
# nav overflow reported against this repo).
class ResponsiveTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ]

  setup { @frame = janela_frames(:orders) }

  # Selenium keeps one browser window for the whole run, so a resize here
  # outlives the test unless it is put back: every test after this one would
  # otherwise inherit a phone width and fail for an unrelated reason.
  teardown { Capybara.current_session.current_window.resize_to(1400, 1400) }

  test "no page is wider than a phone's viewport" do
    Capybara.current_session.current_window.resize_to(*PHONE)

    # A plain Capybara visit rather than the base class's: that override waits
    # for every pane to finish loading, and a pane below the fold on a phone
    # never does, because it is fetched with `loading="lazy"`. Layout width is
    # settled long before that, so there is nothing to wait for here.
    [ root_path, orders_path, gallery_path, the_name_path, docs_path, frame_path(@frame) ].each do |path|
      Capybara.current_session.visit(path)
      # Before its stylesheet lands the page is unstyled, and unstyled content
      # is wider than a phone for reasons that are not a layout bug. The one
      # confirmed occurrence of #50 measured 531px against a 390px viewport,
      # which is what that looks like.
      wait_for_stylesheets

      scroll_width, inner_width = page.evaluate_script("[document.documentElement.scrollWidth, window.innerWidth]")
      assert_operator scroll_width, :<=, inner_width,
        -> { "#{path} scrolls horizontally at a phone width (#{scroll_width} > #{inner_width}):\n#{overflowing_elements}" }
    end
  end

  test "the hamburger reveals the nav links and they still navigate" do
    Capybara.current_session.current_window.resize_to(*PHONE)
    Capybara.current_session.visit(root_path)

    assert_no_selector ".nav-menu[open]"
    find("summary.nav-toggle").click
    assert_selector ".nav-menu[open]"

    click_on "Example"
    assert_current_path orders_path
  end

  test "the page behind the open menu does not scroll" do
    Capybara.current_session.current_window.resize_to(*PHONE)
    Capybara.current_session.visit(root_path)
    # instant, because the demo sets scroll-behavior: smooth and a plain
    # scrollTo is still animating when the assertion below reads scrollY.
    # It arrives eventually, so this failed on a fast machine and passed on
    # CI, which is the worst way for a test to be wrong.
    page.execute_script("window.scrollTo({ top: 300, behavior: 'instant' })")

    find("summary.nav-toggle").click
    assert_selector ".nav-menu[open]"

    # A dispatched wheel event, not window.scrollTo: scrollTo is the JS
    # escape hatch and ignores the overflow that is meant to stop a real
    # gesture, so it would pass even if the lock did nothing.
    page.evaluate_script(<<~JS)
      document.body.dispatchEvent(new WheelEvent("wheel", { deltaY: 400, bubbles: true, cancelable: true }))
    JS
    assert_equal 300, page.evaluate_script("window.scrollY")
  end

  test "the menu's links are centred, not left aligned" do
    Capybara.current_session.current_window.resize_to(*PHONE)
    Capybara.current_session.visit(root_path)

    find("summary.nav-toggle").click
    assert_selector ".nav-menu[open]"

    aligns = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".nav-menu .nav-links a")].map(a => getComputedStyle(a).textAlign)
    JS
    assert_equal [ "center" ] * aligns.length, aligns
  end

  test "the menu does not stay open on a cached back visit" do
    Capybara.current_session.current_window.resize_to(*PHONE)
    Capybara.current_session.visit(root_path)

    find("summary.nav-toggle").click
    assert_selector ".nav-menu[open]"
    click_on "Example"
    assert_current_path orders_path

    find("summary.nav-toggle").click
    assert_selector ".nav-menu[open]"

    # Turbo restores a back visit from its in-memory snapshot rather than a
    # fresh fetch, which is exactly the case a closed-by-default details
    # element on freshly rendered HTML cannot cover.
    page.go_back
    assert_current_path root_path
    assert_no_selector ".nav-menu[open]"
  end
end
