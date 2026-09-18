require "application_system_test_case"

# #42, decided in ADR 029: pointing an existing pane's turbo frame at a URL
# differing only in limit, granularity or renderer used to leave the frame
# stale with no error, because the response was fingerprinted from the
# *new* query and wore an id the frame never had. Turbo had nothing to
# reconcile and dropped the response silently. A named pane's id comes from
# the host instead, so it never moves, and the response now answers to
# whatever frame asked for it rather than to its own query.
class PaneFrameIdentityTest < ApplicationSystemTestCase
  test "changing a named pane's src to a URL differing only in limit updates the frame in place" do
    visit orders_path

    frame = find("turbo-frame#orders-revenue-by-status", visible: :all)
    assert_equal 3, frame.all("tbody tr", visible: :all).size

    # Janela's own frame controller keeps a record of what it last asked
    # each pane for (#33) and reverts any fetch that does not match it, so a
    # control reconfiguring a named pane in place updates that record before
    # changing src, exactly as the gallery's own control does.
    page.execute_script(<<~JS)
      const frame = document.getElementById("orders-revenue-by-status")
      const url = new URL(frame.src, window.location.origin)
      url.searchParams.set("limit", "1")
      frame.dataset.janelaAsked = url.href
      frame.src = url.pathname + url.search
    JS

    within("turbo-frame#orders-revenue-by-status", visible: :all) do
      assert_selector "tbody tr", count: 1, visible: :all
    end
    assert_selector "turbo-frame#orders-revenue-by-status", visible: :all
  end
end
