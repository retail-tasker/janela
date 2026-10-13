require "test_helper"

class VisitsPageTest < ActionDispatch::IntegrationTest
  test "the visits page is a frame of the page views, counting itself" do
    frame = Janela::Frame.create!(name: PageView::FRAME, owner: customers(:acme))
    frame.panes.create!(model: "page_views", measure: "views")
    PageView.record(controller: "docs", action: "show", path: "/docs/agents")

    get visits_path

    assert_response :success
    assert_select "h1", "Visits"
    # The earlier view and this one, recorded after the page is built.
    assert_select ".janela-value-number", "1"
  end

  test "the visits page says so when its frame has not been seeded" do
    get visits_path

    assert_response :success
    assert_select "p", /not been set up/
  end
end
