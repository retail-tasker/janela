require "application_system_test_case"

class CrossFilteringTest < ApplicationSystemTestCase
  test "clicking a value re-scopes the other visuals" do
    visit root_path

    within_visual("Revenue by Status") { assert_text "300.0" }

    within_visual("Revenue by Region") { click_on "APAC" }

    within_visual("Revenue by Status") do
      assert_text "100.0"
      assert_no_text "pending"
    end
  end

  test "a visual does not filter itself" do
    visit root_path

    within_visual("Revenue by Region") do
      click_on "APAC"
      assert_text "EU"
      assert_text "225.0"
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
    within_visual("Revenue by Status") { assert_text "100.0" }

    click_on "Clear filters"

    within_visual("Revenue by Status") { assert_text "300.0" }
  end

  private
    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
