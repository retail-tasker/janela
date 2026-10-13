require "test_helper"

# ADR 055, #75 and #80. A category pane was ordered by its measure, largest
# first, and could be ordered no other way. Two things were believed that the
# measuring did not bear out: that reversing the rows in the view would give
# the bottom N (the limit is applied in SQL first, so it gives the top N
# reversed), and that a sort by label needed a decision about text against the
# column's type (the database sorts the column as its own type, so there was
# nothing to decide). The fixtures: paid 2 orders and 300, refunded 1 and 50,
# pending 1 and 25; channels web 300, phone 50, and one order with none.
class SortTest < ActionDispatch::IntegrationTest
  def keys(sort, measure: :revenue, by: :status, **options)
    Order.janela.query(measure, by: by, sort: sort, **options).keys
  end

  test "unset and desc are the order a pane always had" do
    assert_equal %w[paid refunded pending], keys(nil)
    assert_equal %w[paid refunded pending], keys("desc")
  end

  # #75. The limit follows the order, so this is the bottom two and not the
  # top two turned round.
  test "asc is the smallest first, and a limit keeps the smallest" do
    assert_equal %w[pending refunded paid], keys("asc")
    assert_equal %w[pending refunded], keys("asc", limit: 2)
    assert_equal %w[paid refunded], keys("desc", limit: 2)
  end

  # #80.
  test "label is the dimension's own value, ascending, and label_desc the reverse" do
    assert_equal %w[paid pending refunded], keys("label")
    assert_equal %w[refunded pending paid], keys("label_desc")
  end

  test "a limit follows a label order: the first labels, not the largest" do
    assert_equal %w[paid pending], keys("label", limit: 2)
  end

  test "a dimension reached through an association sorts by its own column" do
    assert_equal %w[Acme Globex], keys("label", by: :customer)
    assert_equal %w[Globex Acme], keys("label_desc", by: :customer)
  end

  # The database puts NULL first in an ascending order on SQLite and last on
  # PostgreSQL, so left alone a label order differs by host (ADR 055).
  test "the (none) group is last in every order that is about the label" do
    assert_equal %w[phone web (none)], keys("label", by: :channel)
    assert_equal %w[web phone (none)], keys("label_desc", by: :channel)
  end

  # Paid has 2 orders, and refunded and pending have 1 each. Without a
  # tiebreak the choice between the two ones is the database's, and with a limit
  # it decides which of them is shown at all.
  test "groups tied on the measure come out by label, in either direction" do
    assert_equal %w[paid pending refunded], keys("desc", measure: :orders)
    assert_equal %w[pending refunded paid], keys("asc", measure: :orders)
    assert_equal %w[pending], keys("asc", measure: :orders, limit: 1)
  end

  test "a time dimension is ordered by time whatever the sort says" do
    plain = Order.janela.query(:revenue, by: :placed_on).keys
    assert_equal plain, Order.janela.query(:revenue, by: :placed_on, sort: "asc").keys
    assert_equal plain, Order.janela.query(:revenue, by: :placed_on, sort: "label_desc").keys
  end

  test "a sort that is not one of the four is refused" do
    assert_raises(Janela::BadRequest) { keys("sideways") }
    assert_raises(Janela::BadRequest) { keys("label desc") }
  end

  test "the pane URL carries it, and the page is in that order" do
    get janela.pane_path("orders", "revenue", "status", sort: "asc")

    assert_response :success
    assert_equal %w[pending refunded paid], css_select("td").map { |cell| cell.text.strip }.grep(/\A(paid|pending|refunded)\z/)
  end

  test "a bad sort in the URL is a 400 that names nothing internal" do
    get janela.pane_path("orders", "revenue", "status", sort: "sideways")

    assert_response :bad_request
    assert_select "p.janela-error", "That request is not allowed on this pane."
  end

  test "a time pane and a single value ignore it" do
    [ [ "placed_on", nil ], [ nil, nil ] ].each do |dimension, _|
      get janela.pane_path("orders", "revenue", *dimension, sort: "asc")
      assert_response :success
    end
  end

  # Top five and bottom five of one breakdown are different answers and may
  # share a page, as limit is, so a set sort is part of the id. Unset is the
  # id every frame already has (ADR 007, ADR 055).
  test "a sort that is set is part of the frame id and an unset one changes no id" do
    base = { model: Order, measure: :revenue, by: :customer, as: :table, limit: 5 }

    assert_equal "janela_orders_revenue_customer_table_top5", Janela::Query.turbo_frame_id(**base)
    assert_equal "janela_orders_revenue_customer_table_top5", Janela::Query.turbo_frame_id(**base, sort: "desc")
    assert_equal "janela_orders_revenue_customer_table_top5_asc", Janela::Query.turbo_frame_id(**base, sort: "asc")
  end

  # Snapshots found a pane by its key, and ones taken before this have no
  # sort in theirs. A key with sort: nil in it would stop finding them.
  test "a snapshot taken before there was a sort is still found, and a set sort is part of the key" do
    snapshot = Janela::Snapshot.take(name: "September", owner: customers(:acme), taken_at: Time.utc(2026, 9, 15)) do |take|
      take.pane Order, :revenue, by: :status
    end
    plain = Janela::Query.new(definition: Order.janela, measure: :revenue, dimension: :status)
    asc = Janela::Query.new(definition: Order.janela, measure: :revenue, dimension: :status, sort: "asc")

    assert_not_includes plain.lookup_key.keys, "sort"
    assert_equal "asc", asc.lookup_key["sort"]
    assert snapshot.stored_result(plain)
    assert_raises(Janela::NotFound) { snapshot.stored_result(asc) }
  end

  test "a stored pane carries it from the row, so a refresh keeps it" do
    pane = janela_frames(:orders).panes.create!(model: "orders", measure: "revenue", dimension: "status", sort: "label")

    get janela.frame_pane_path(janela_frames(:orders), pane)

    assert_equal %w[paid pending refunded], css_select("td").map { |cell| cell.text.strip }.grep(/\A(paid|pending|refunded)\z/)
  end

  test "a stored pane refuses a sort that is not one of the four" do
    pane = janela_frames(:orders).panes.build(model: "orders", measure: "revenue", dimension: "status", sort: "sideways")

    assert_not pane.valid?
    assert_includes pane.errors.attribute_names, :sort
  end

  test "the pane form offers it as a select, with blank meaning largest first" do
    get janela.edit_frame_pane_path(janela_frames(:orders), janela_panes(:revenue_total))

    assert_select "select[name='pane[sort]'] option", count: 4
    assert_select "select[name='pane[sort]'] option[value='']", text: "Largest first"
  end

  test "the form saves it, and clearing it leaves the pane as it was before" do
    pane = janela_panes(:revenue_by_status_bar)

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { sort: "asc" } }
    assert_equal "asc", pane.reload.sort

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { sort: "" } }
    assert_nil pane.reload.sort
  end

  test "janela_pane puts it in the pane's URL, only when asked" do
    get orders_path

    assert_select "turbo-frame[data-janela-src*='sort=']", minimum: 1
    assert_select "turbo-frame[data-janela-src*='sort=asc']", minimum: 1
  end

  test "an agent can set it, and the tool's schema names the four values" do
    tools = Janela::Tools.new(scope: ->(model) { model.all }, write: true)
    frame = janela_frames(:orders)

    pane = tools.call("add_pane", frame_id: frame.id, model: "orders", measure: "revenue", dimension: "status", sort: "asc")

    assert_equal "asc", pane[:sort]
    add = Janela::Tools.all(write: true).find { |tool| tool.name == "add_pane" }
    assert_equal %w[desc asc label label_desc], add.input_schema[:properties][:sort][:enum]
  end

  test "Janela.sorts is the supported enumeration, so a page does not reach into a constant" do
    assert_equal %w[desc asc label label_desc], Janela.sorts
  end
end
