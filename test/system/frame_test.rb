require "application_system_test_case"

# A frame built from rows in a real browser: it must be right before any
# JavaScript runs, and still cross-filter once Turbo is there (ADR 014).
class FrameTest < ApplicationSystemTestCase
  setup { @frame = janela_frames(:orders) }

  test "a frame from rows renders inline and keeps its panes unfetched" do
    visit frame_path(@frame)

    within_pane("Where the money is") { assert_text "$225.00" }
    assert_selector "canvas.janela-chart[aria-label='Revenue by Status']"
    assert_equal [ nil ] * 4, all("turbo-frame", visible: :all).map { |pane| pane[:src] }
  end

  test "clicking a value in a frame from rows re-scopes the other panes" do
    visit frame_path(@frame)
    within_value("Revenue") { assert_text "$375.00" }

    within_pane("Where the money is") { click_on "APAC" }

    within_value("Revenue") { assert_text "$150.00" }
    within_pane("Where the money is") do
      assert_text "$225.00"
      assert_selector "button[aria-pressed=true]", text: "APAC"
    end
    assert_includes current_url, "q%5Bcustomer_region_eq%5D=APAC"
  end

  test "a frame from rows opened from a filtered link is already filtered" do
    visit frame_path(@frame, q: { status_eq: "paid" })

    within_value("Revenue") { assert_text "$300.00" }
    within_pane("Where the money is") { assert_no_text "$225.00" }
  end

  private
    def within_value(label, &block)
      within(:xpath, "//p[contains(@class, 'janela-value')][span[text()='#{label}']]", &block)
    end

    def within_pane(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
