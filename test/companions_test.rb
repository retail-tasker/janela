require "test_helper"

# ADR 051, #34. Believed (#34): an attribute is "resolved from the same row the
# dimension came from". Measured: a group has many rows, and grouping by the
# attribute multiplies them, MAX shows an arbitrary one as fact, and only a
# value shared by every row can be shown honestly. The fixtures: Acme (APAC)
# and Globex (EU) have two orders each; the two paid orders come from two
# regions; two of the four orders are expedited, both paid.
class CompanionsTest < ActionDispatch::IntegrationTest
  def cells(row)
    css_select("table.janela-pane tbody tr:nth-of-type(#{row}) td").map { |cell| cell.text.strip }
  end

  def headers
    css_select("table.janela-pane thead th").map { |cell| cell.text.strip }
  end

  def get_pane(measure, dimension, **params)
    get janela.pane_path("orders", measure, dimension, **params)
  end

  test "a measure companion is a second column, with a header row to name it" do
    get_pane "revenue", "customer", companions: [ "orders" ]

    assert_equal [ "Customer", "Revenue", "Orders" ], headers
    assert_equal [ "Globex", "$225.00", "2" ], cells(1)
    assert_equal [ "Acme", "$150.00", "2" ], cells(2)
  end

  # The half the issue called more valuable: 75% of four or of forty.
  test "a rate can sit beside the count behind it, each formatted as it declares" do
    get_pane "expedited_rate", "customer", companions: [ "orders" ]

    assert_equal [ "Customer", "Expedited rate", "Orders" ], headers
    assert_equal [ "50.0%", "2" ], cells(1).drop(1)
  end

  test "a dimension companion shows the value its whole group shares" do
    get_pane "revenue", "customer", companions: [ "region" ]

    assert_equal [ "Customer", "Revenue", "Region" ], headers
    assert_equal [ "Globex", "$225.00", "EU" ], cells(1)
    assert_equal [ "Acme", "$150.00", "APAC" ], cells(2)
  end

  # Grouping by both would show paid twice, and MAX would show it as EU. Both
  # were measured. A group whose rows disagree shows nothing.
  test "a dimension companion is blank where the group's rows disagree, not a guess" do
    get_pane "revenue", "status", companions: [ "region" ]

    rows = css_select("table.janela-pane tbody tr").map { |row| row.css("td").map { |cell| cell.text.strip } }
    assert_equal 3, rows.size, "one row per status, not one per status and region"
    assert_equal [ "paid", "$300.00", "" ], rows.find { |row| row.first == "paid" }
    assert_equal [ "refunded", "$50.00", "APAC" ], rows.find { |row| row.first == "refunded" }
    assert_equal [ "pending", "$25.00", "EU" ], rows.find { |row| row.first == "pending" }
  end

  test "the order and the limit belong to the primary measure, not to a companion" do
    get_pane "revenue", "status", limit: 2, companions: [ "orders" ]

    labels = css_select("table.janela-pane tbody tr").map { |row| row.css("td").first.text.strip }
    assert_equal %w[paid refunded], labels
    assert_equal [ "2", "1" ], css_select("table.janela-pane tbody tr").map { |row| row.css("td").last.text.strip }
  end

  test "a filter on another dimension narrows the companions too" do
    get_pane "revenue", "status", companions: [ "orders" ], q: { customer_region_in: [ "APAC" ] }

    paid = css_select("table.janela-pane tbody tr").find { |row| row.css("td").first.text.strip == "paid" }
    assert_equal [ "paid", "$100.00", "1" ], paid.css("td").map { |cell| cell.text.strip }
  end

  test "a time pane may carry a measure beside each bucket" do
    get_pane "revenue", "placed_on", granularity: "month", companions: [ "orders" ]

    assert_equal [ "Placed on", "Revenue", "Orders" ], headers
    assert_equal [ "Sep 2026", "$375.00", "4" ], cells(1)
  end

  test "the label is still the click target, unchanged" do
    get_pane "revenue", "customer", companions: [ "orders", "region" ]

    assert_select "table.janela-pane tbody tr td:first-child button[data-janela--frame-key-param='customer_name_in']", 2
  end

  test "with no companions a table is exactly what it was: two cells and no header row" do
    get_pane "revenue", "customer"

    assert_select "table.janela-pane thead", count: 0
    assert_equal 2, cells(1).size
  end

  test "a chart, a ring and a single value ignore companions" do
    get_pane "revenue", "customer", as: "bar", companions: [ "orders" ]
    assert_response :success
    assert_select "table", count: 0

    get_pane "revenue", "customer", as: "doughnut", companions: [ "orders" ]
    assert_response :success
    assert_select "table.janela-pane", count: 0

    get janela.pane_path("orders", "revenue", companions: [ "orders" ])
    assert_response :success
    assert_select ".janela-value-number", "$375.00"
  end

  test "a stored snapshot shows the base table only" do
    snapshot = Janela::Snapshot.take(name: "September", owner: customers(:acme), taken_at: Time.utc(2026, 9, 15)) do |take|
      take.pane Order, :revenue, by: :customer
    end

    get janela.snapshot_pane_path(snapshot, "orders", "revenue", "customer", companions: [ "orders" ])

    assert_response :success
    assert_select "table.janela-pane thead", count: 0
    assert_equal 2, css_select("table.janela-pane tbody tr:first-child td").size
  end

  test "what may be named is a declared measure or dimension, and refusals name nothing internal" do
    [
      { companions: [ "no_such_thing" ] },
      { companions: [ "revenue" ] },        # the pane's own measure
      { companions: [ "customer" ] },       # the pane's own dimension
      { companions: [ "placed_on" ] },      # a time dimension is not a fact about a label
      { companions: [ "orders", "orders" ] },
      { companions: [ "orders", "region", "channel", "status" ] },
      { companions: "orders" },
      { companions: { "0" => "orders" } }
    ].each do |params|
      get_pane "revenue", "customer", **params

      assert_response :bad_request, params.inspect
      assert_select "p.janela-error", "That request is not allowed on this pane."
    end
  end

  test "a dimension companion on a time pane is refused, since a bucket has no shared fact" do
    get_pane "revenue", "placed_on", granularity: "month", companions: [ "region" ]

    assert_response :bad_request
  end

  test "three companions are the most a pane may run" do
    get_pane "revenue", "customer", companions: [ "orders", "average_order", "region" ]

    assert_response :success
    assert_equal 5, headers.size
  end

  test "a stored pane carries its companions from the row, so a refresh keeps them" do
    pane = janela_frames(:orders).panes.create!(model: "orders", measure: "revenue", dimension: "customer", companions: %w[orders region])

    get janela.frame_pane_path(janela_frames(:orders), pane)

    assert_equal [ "Customer", "Revenue", "Orders", "Region" ], headers
  end

  test "a stored pane validates its companions against the model when it is saved" do
    frame = janela_frames(:orders)
    pane = ->(companions) { frame.panes.new(model: "orders", measure: "revenue", dimension: "customer", companions: companions) }

    assert_predicate pane.(nil), :valid?
    assert_predicate pane.([ "orders", "region" ]), :valid?
    assert_predicate pane.([ "", "orders" ]), :valid?, "the blank a multiple select sends is not a companion"
    [ [ "nope" ], [ "revenue" ], [ "customer" ], [ "placed_on" ], %w[orders average_order region channel] ].each do |bad|
      assert_not_predicate pane.(bad), :valid?, bad.inspect
    end
    assert_nil pane.([ "" ]).tap(&:valid?).companions, "an empty selection is nothing, not an empty list"
  end

  test "the pane form offers the model's other measures and dimensions" do
    get janela.edit_frame_pane_path(janela_frames(:orders), janela_panes(:revenue_by_region))

    assert_select "select[name='pane[companions][]'][multiple]"
    values = css_select("select[name='pane[companions][]'] option").map { |option| option["value"] }.reject(&:blank?)
    assert_includes values, "orders"
    assert_includes values, "status"
    assert_not_includes values, "revenue", "the pane's own measure"
    assert_not_includes values, "region", "the pane's own dimension"
    assert_not_includes values, "placed_on", "a time dimension"
  end

  test "the form saves companions, and clearing them clears them" do
    pane = janela_panes(:revenue_by_region)

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { companions: [ "", "orders", "channel" ] } }
    assert_equal %w[orders channel], pane.reload.companions

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { companions: [ "" ] } }
    assert_nil pane.reload.companions
  end

  test "janela_pane puts the companions in its URL and leaves the frame id alone" do
    get orders_path

    assert_select "turbo-frame#janela_orders_revenue_customer_table_top5[data-janela-src*='companions%5B%5D=orders']"
  end

  # A companion is fetched for the labels the primary chose, and not for its own
  # top 1000, which for a wide dimension could leave a chosen label without one.
  # With a handful of fixtures the numbers agree either way, so the restriction
  # is asserted on the query itself.
  test "a companion query is narrowed to the labels it is asked for, the null group included" do
    definition = Order.janela

    assert_equal({ "paid" => 2 }, definition.query(:orders, by: :status, keys: [ "paid" ]))
    assert_equal({ "web" => 2, Janela::Dimension::NONE => 1 }, definition.query(:orders, by: :channel, keys: [ "web", Janela::Dimension::NONE ]))
    assert_equal({ "web" => { region: "APAC" } }.keys, definition.facts([ :region ], by: :channel, keys: [ "web" ]).keys)
  end

  test "the null group gets its companions too" do
    get_pane "orders", "channel", companions: [ "expedited_rate", "region" ]

    none = css_select("table.janela-pane tbody tr").find { |row| row.css("td").first.text.strip == "(none)" }
    assert_equal [ "(none)", "1", "0.0%", "EU" ], none.css("td").map { |cell| cell.text.strip }
  end
end
