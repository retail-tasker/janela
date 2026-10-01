require "application_system_test_case"

# The front page's Clear filters button is the demo's own markup wired to
# Janela's janela--frame#clear action, so what is worth proving is that the
# action is reachable from outside the frame and that the button only shows
# while something is selected.
class ClearTest < ApplicationSystemTestCase
  test "the button appears with a selection and clears it" do
    visit root_path
    assert_no_selector "button", text: "Clear filters"

    within(:xpath, "//figure[figcaption[text()='Orders by Status']]") { click_on "paid" }
    assert_selector "button", text: "Clear filters"
    assert_frame_filters({ "status_in" => [ "paid" ] })

    click_on "Clear filters"

    assert_no_selector "button", text: "Clear filters"
    assert_frame_filters({})
  end

  test "a filtered link opens with the button already showing" do
    visit root_path(q: { status_in: [ "paid" ] })

    assert_selector "button", text: "Clear filters"
  end

  private
end
