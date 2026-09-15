require "application_system_test_case"

class CrossFilteringTest < ApplicationSystemTestCase
  test "clicking a value re-scopes the other panes, including the single total" do
    visit root_path

    within_visual("Revenue by Status") { assert_text "$300.00" }
    within_value("Revenue") { assert_text "$375.00" }

    within_visual("Revenue by Region") { click_on "APAC" }

    within_visual("Revenue by Status") do
      assert_text "$100.00"
      assert_no_text "pending"
    end
    within_value("Revenue") { assert_text "$150.00" }
  end

  test "a visual does not filter itself but marks the selected value" do
    visit root_path

    within_visual("Revenue by Region") do
      click_on "APAC"
      assert_text "EU"
      assert_text "$225.00"
      assert_selector "button[aria-pressed=true]", text: "APAC"
      assert_selector "button[aria-pressed=false]", text: "EU"
    end
  end

  test "filters from different visuals intersect" do
    visit root_path

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { click_on "paid" }

    within_visual("Orders by Region") do
      assert_selector "td", text: "1"
      assert_no_selector "td", text: "2"
    end
  end

  test "clicking the same value again removes the filter" do
    visit root_path

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { assert_no_text "pending" }

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { assert_text "pending" }
  end

  test "clearing resets every visual" do
    visit root_path

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { assert_text "$100.00" }

    click_on "Clear filters"

    within_visual("Revenue by Status") { assert_text "$300.00" }
  end

  test "filters live in the page URL and survive a reload" do
    visit root_path
    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { assert_text "$100.00" }

    assert_includes current_url, "q%5Bcustomer_region_eq%5D=APAC"

    visit current_url
    within_visual("Revenue by Status") { assert_text "$100.00" }
    within_visual("Revenue by Region") { assert_selector "button[aria-pressed=true]", text: "APAC" }

    click_on "Clear filters"
    within_visual("Revenue by Status") { assert_text "$300.00" }
    assert_not_includes current_url, "q%5B"
  end

  test "a dashboard opened from a filtered link renders filtered before any click" do
    visit root_path(q: { status_eq: "paid" })

    within_visual("Revenue by Region") do
      assert_text "$100.00"
      assert_text "$200.00"
      assert_no_text "$225.00"
    end
    within_value("Revenue") { assert_text "$300.00" }
  end

  private
    def within_value(label, &block)
      within(:xpath, "//p[contains(@class, 'janela-value')][span[text()='#{label}']]", &block)
    end

    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
