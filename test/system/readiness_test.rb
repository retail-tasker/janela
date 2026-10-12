require "application_system_test_case"

# The readiness the suite waits on before it clicks (#56).
class ReadinessTest < ApplicationSystemTestCase
  # Believed: a dashboard is ready for a click once no pane is busy. False for
  # the moment after a click. The frame hears a selection through a mutation
  # observer, so for a task or so no pane has been told to refetch, none is
  # busy, and a second click made then goes to a button that the first click's
  # refetch is about to replace. Nothing hears it. CI lost one in sixty that
  # way across three different tests, each making two clicks in a row, and
  # every pane in every failure had settled on the first click's filters.
  test "a selection the frame has not yet acted on is not a ready dashboard" do
    visit orders_path

    state = page.evaluate_script(<<~JS)
      (() => {
        const frame = document.querySelector("[data-controller~='janela--frame']")
        frame.setAttribute("data-janela--frame-filters-value", JSON.stringify({ status_in: [ "paid" ] }))
        return (#{READINESS_SCRIPT.strip})
      })()
    JS

    assert_equal false, state["ready"], "ready in the same task as the click, before any pane could have been told"
  end

  test "and is ready again once every pane has fetched for it" do
    visit orders_path
    within_visual("Revenue by Status") { click_on "paid" }

    wait_for_frames
    assert page.evaluate_script(READINESS_SCRIPT)["ready"]
    assert_equal({ "status_in" => [ "paid" ] }, frame_filters)
  end

  private
    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    end
end
