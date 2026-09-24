require "application_system_test_case"

# The host's fixed filter survives everything a reader can do to the frame's
# own filters (ADR 040, #57). Measured before the decision: a host filter in
# q[...] was removed by Clear filters and by Escape, and the page showed every
# order under a heading that said paid. Fixtures: $375 in all, $300 paid, and
# $100 of the paid in APAC.
class FixedFilterSystemTest < ApplicationSystemTestCase
  test "clearing the reader's filters leaves the host's in place" do
    visit orders_for_status_path("paid")
    within_value("Revenue") { assert_text "$300.00" }

    within_visual("Revenue by Region") { click_on "APAC" }
    within_value("Revenue") { assert_text "$100.00" }

    click_on "Clear filters"

    within_value("Revenue") do
      assert_text "$300.00"
      assert_no_text "$375.00"
    end
    refute_includes current_url, "where"
  end

  # Repointed to a different dimension, so the numbers say both that the
  # repoint happened and which rows it read: EU is $200 of the paid orders
  # and $225 of all of them. A repoint to the same dimension proved nothing,
  # since the pane showed one paid row whether it had moved or not.
  test "a repointed pane keeps the host's fixed filter" do
    visit orders_for_status_path("paid")
    within("turbo-frame#orders-revenue-by-status", visible: :all) { assert_no_text "pending" }

    page.execute_script(<<~JS)
      document.getElementById("orders-revenue-by-status").dispatchEvent(
        new CustomEvent("janela--frame:repoint", { bubbles: true, detail: { url: "#{janela.pane_path("orders", "revenue", "region")}" } })
      )
    JS

    within("turbo-frame#orders-revenue-by-status", visible: :all) do
      assert_text "EU"
      assert_text "$200.00"
      assert_no_text "$225.00"
    end
  end

  private
    def within_value(label, &block)
      within(:xpath, "//p[contains(@class, 'janela-value')][span[text()='#{label}']]", &block)
    end

    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
