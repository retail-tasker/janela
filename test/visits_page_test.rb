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

  # The visits frame is kept through a reset, so it is the oldest frame in the
  # demo, and the orders page used to link to whichever frame came first (ADR 058).
  test "the orders page links to the orders frame, not whichever frame is oldest" do
    Janela::Frame.destroy_all
    Janela::Frame.create!(name: PageView::FRAME, owner: customers(:acme))
    orders = Janela::Frame.create!(name: "Orders, from the database", owner: customers(:acme))

    get orders_path

    assert_select "a[href=?]", frame_path(orders)
  end
end
