require "test_helper"

# A host fixes a filter when it renders a frame, and the reader's selection
# can only narrow inside it (ADR 040, #57). It was believed a host could do
# this with q[...] in the page URL; it cannot, because q[...] is the reader's,
# and Clear filters, Escape and a click on the same dimension all remove it.
# Fixtures: $375 in all, $300 of it paid, $25 pending.
class FixedFilterTest < ActionDispatch::IntegrationTest
  test "a pane applies the host's fixed filter" do
    get janela.pane_path("orders", "revenue", where: { status_eq: "paid" })

    assert_response :success
    assert_select ".janela-value-number", "$300.00"
  end

  # Two conditions, both applied. A reader's selection on the same column
  # asks for rows that are paid and pending at once, which is none, rather
  # than replacing the host's condition and reaching the pending ones.
  test "the reader's filter narrows inside the fixed one and cannot widen it" do
    get janela.pane_path("orders", "revenue", where: { status_eq: "paid" }, q: { status_in: [ "pending" ] })

    assert_response :success
    assert_select ".janela-value-number", "$0.00"
  end

  test "a fixed filter is bounded like any other, so an undeclared column is refused" do
    get janela.pane_path("orders", "revenue", where: { amount_gt: "0" })

    assert_response :bad_request
  end

  test "a stored frame's pane applies the fixed filter too" do
    frame = janela_frames(:orders)

    get janela.frame_pane_path(frame, janela_panes(:revenue_total), where: { status_eq: "paid" })

    assert_response :success
    assert_select ".janela-value-number", "$300.00"
  end

  test "a stored frame rendered with a fixed filter is already narrowed, and the filter is not the reader's" do
    frame = janela_frames(:orders)
    pane = janela_panes(:revenue_total)

    get frame_for_status_path(frame, "paid")

    assert_response :success
    assert_select "turbo-frame##{pane.turbo_frame_id} .janela-value-number", "$300.00"
    assert_select "turbo-frame[data-janela-src=?]", "/dashboards/#{frame.id}/panes/#{pane.id}?where%5Bstatus_eq%5D=paid"
    # The reader's filter state starts empty, so nothing the reader does to it
    # can reach the host's filter.
    assert_select "[data-janela--frame-filters-value=?]", "{}"
  end

  test "a hand written frame carries the fixed filter into every pane it composes" do
    get orders_for_status_path("paid")

    assert_response :success
    assert_select "turbo-frame[data-janela-src=?]", "/dashboards/orders/revenue?where%5Bstatus_eq%5D=paid"
    assert_select "[data-janela--frame-filters-value=?]", "{}"
  end

  # The server's src and the controller's rebuilt one have to be the same
  # string, or the controller treats the first load as stale and fetches
  # every pane twice (#33). Rails sorts query parameters, which would put q
  # before where; the controller appends q last.
  test "a pane's first src puts the reader's filters after the fixed one, as the controller does" do
    get orders_for_status_path("paid", q: { customer_region_in: [ "APAC" ] })

    assert_select "turbo-frame[src=?]", "/dashboards/orders/revenue?where%5Bstatus_eq%5D=paid&q%5Bcustomer_region_in%5D%5B%5D=APAC"
  end
end
