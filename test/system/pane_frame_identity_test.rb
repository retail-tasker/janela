require "application_system_test_case"

# #42, decided in ADR 029: pointing an existing pane's turbo frame at a URL
# differing only in limit, granularity or renderer used to leave the frame
# stale with no error, because the response was fingerprinted from the
# *new* query and wore an id the frame never had. Turbo had nothing to
# reconcile and dropped the response silently. A named pane's id comes from
# the host instead, so it never moves, and the response now answers to
# whatever frame asked for it rather than to its own query.
#
# ADR 029 then said a host writes the frame's src. #43 found that it cannot:
# the frame controller reverts any fetch that is not what it last asked for
# (#33), so this test used to set that record by hand first, which was the
# workaround rather than the API. A host asks the frame controller instead
# (ADR 030), and that is what is exercised here.
class PaneFrameIdentityTest < ApplicationSystemTestCase
  test "repointing a named pane at a URL differing only in limit updates the frame in place" do
    visit orders_path

    frame = find("turbo-frame#orders-revenue-by-status", visible: :all)
    assert_equal 3, frame.all("tbody tr", visible: :all).size

    repoint "orders-revenue-by-status", janela.pane_path("orders", "revenue", "status", limit: 1)

    within("turbo-frame#orders-revenue-by-status", visible: :all) do
      assert_selector "tbody tr", count: 1, visible: :all
    end
    assert_selector "turbo-frame#orders-revenue-by-status", visible: :all
  end

  # #43: only the frame controller knows what the frame is filtered to, so
  # reapplying the filters is part of repointing rather than something a
  # caller has to remember. Forgetting it is silent: the pane shows numbers
  # for a filter state nobody is in, beside panes that are still filtered
  # (ADR 003, ADR 030). APAC is $100 of the $300 paid, so an unfiltered pane
  # reads $300.00 here.
  test "a repointed pane keeps the filters the rest of the frame is showing" do
    visit orders_path

    within_visual("Revenue by Region") { click_on "APAC" }
    within("turbo-frame#orders-revenue-by-status", visible: :all) { assert_text "$100.00" }

    repoint "orders-revenue-by-status", janela.pane_path("orders", "revenue", "status", limit: 1)

    within("turbo-frame#orders-revenue-by-status", visible: :all) do
      assert_selector "tbody tr", count: 1, visible: :all
      assert_text "$100.00"
      assert_no_text "$300.00"
    end
  end

  private
    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end

    # The one call a host makes, and the whole of it: name the pane it is for,
    # and the query to go to. Filters are the frame's, so nothing here says
    # anything about them.
    def repoint(id, url)
      page.execute_script(<<~JS)
        document.getElementById("#{id}").dispatchEvent(
          new CustomEvent("janela--frame:repoint", { bubbles: true, detail: { url: "#{url}" } })
        )
      JS
    end
end
