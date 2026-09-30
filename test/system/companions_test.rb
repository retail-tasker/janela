require "application_system_test_case"

# ADR 051. The cells the server renders prove nothing about the click, so this
# drives the real gesture from a table that has companion columns.
class CompanionsSystemTest < ApplicationSystemTestCase
  test "a table with companions still filters the rest when its label is clicked" do
    visit orders_path
    within_table("Revenue by Customer") do
      assert_selector "th", text: "Orders"
      assert_selector "th", text: "Region"
      assert_selector "td.janela-fact", text: "APAC"
    end
    within_table("Revenue by Region") { assert_text "$225.00" }

    within_table("Revenue by Customer") { click_on "Acme" }

    assert_equal({ "customer_name_in" => [ "Acme" ] }, eventually({ "customer_name_in" => [ "Acme" ] }) { frame_filters })
    within_table("Revenue by Region") do
      assert_text "$150.00"
      assert_no_text "$225.00"
    end
    within_table("Revenue by Customer") do
      assert_selector "button[aria-pressed=true]", text: "Acme"
      assert_selector "td", text: "Globex", wait: 1
    end
  end

  private
    def within_table(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end

    def eventually(expected)
      20.times do
        actual = yield
        return actual if actual == expected

        sleep 0.1
      end
      yield
    end

    def frame_filters
      wait_for_frames
      JSON.parse(find("[data-controller='janela--frame']", match: :first)["data-janela--frame-filters-value"] || "{}")
    end
end
