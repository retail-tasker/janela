require "test_helper"

# ADR 054, #76. A bar chart had no way to put each bar's value on the bar: the
# controller held the measure's formatted strings and used them only in the
# tooltip. These read what the page asks of the chart; the system test reads
# what was drawn.
class ValueLabelsTest < ActionDispatch::IntegrationTest
  test "with none set a bar chart asks for nothing: no attribute" do
    get janela.pane_path("orders", "revenue", "status", as: "bar")

    assert_select "canvas[data-janela--chart-value-labels-value]", count: 0
  end

  test "value_labels on a bar chart tells the chart controller" do
    get janela.pane_path("orders", "revenue", "status", as: "bar", value_labels: 1)

    assert_select "canvas[data-janela--chart-value-labels-value=true]"
  end

  # A pane switched between renderers keeps the flag, so it is ignored where
  # there is no bar to label and is not an error (ADR 054, as height on a ring).
  test "a line, a ring, a table and a single value ignore it" do
    [ [ "status", "line" ], [ "status", "doughnut" ], [ "status", nil ], [ nil, nil ] ].each do |dimension, renderer|
      get janela.pane_path("orders", "revenue", *dimension, **{ as: renderer, value_labels: 1 }.compact)

      assert_response :success
      assert_select "[data-janela--chart-value-labels-value]", count: 0
    end
  end

  test "a value that is not a yes or a no is a 400 that names nothing internal" do
    [ "maybe", "2", "yes please" ].each do |bad|
      get janela.pane_path("orders", "revenue", "status", as: "bar", value_labels: bad)

      assert_response :bad_request, bad
      assert_select "p.janela-error", "That request is not allowed on this pane."
    end
  end

  test "an explicit no is the same as unset" do
    [ "0", "false" ].each do |no|
      get janela.pane_path("orders", "revenue", "status", as: "bar", value_labels: no)

      assert_response :success
      assert_select "canvas[data-janela--chart-value-labels-value]", count: 0
    end
  end

  test "a snapshot pane takes it too" do
    snapshot = Janela::Snapshot.take(name: "September", owner: customers(:acme), taken_at: Time.utc(2026, 9, 15)) do |take|
      take.pane Order, :revenue, by: :status
    end

    get janela.snapshot_pane_path(snapshot, "orders", "revenue", "status", as: "bar", value_labels: 1)

    assert_select "canvas[data-janela--chart-value-labels-value=true]"
  end

  test "a stored pane carries it from the row, so a refresh keeps it" do
    pane = janela_frames(:orders).panes.create!(model: "orders", measure: "revenue", dimension: "status", renderer: "bar", value_labels: true)

    get janela.frame_pane_path(janela_frames(:orders), pane)

    assert_select "canvas[data-janela--chart-value-labels-value=true]"
  end

  test "the pane form offers it as a checkbox" do
    get janela.edit_frame_pane_path(janela_frames(:orders), janela_panes(:revenue_total))

    assert_select "input[type=checkbox][name='pane[value_labels]']"
  end

  test "the form saves it, and clearing it leaves the pane as it was before" do
    pane = janela_panes(:revenue_by_status_bar)

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { value_labels: "1" } }
    assert pane.reload.value_labels

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { value_labels: "0" } }
    assert_not pane.reload.value_labels
  end

  # It is how a pane is drawn, not which query it is (ADR 029), and it has to
  # be in the URL because the server draws the pane again on every click.
  test "janela_pane puts it in its URL, only when asked, and leaves the frame id alone" do
    get orders_path

    assert_select "turbo-frame#janela_orders_expedited_rate_channel_bar[data-janela-src*='value_labels=1']"
    assert_select "turbo-frame[data-janela-src*='value_labels=']", count: 1
  end

  test "an agent can set it, and it is offered in the tool's schema" do
    tools = Janela::Tools.new(scope: ->(model) { model.all }, write: true)
    frame = janela_frames(:orders)

    pane = tools.call("add_pane", frame_id: frame.id, model: "orders", measure: "revenue", dimension: "status", renderer: "bar", value_labels: true)

    assert_equal true, pane[:value_labels]
    add = Janela::Tools.all(write: true).find { |tool| tool.name == "add_pane" }
    assert_equal "boolean", add.input_schema[:properties][:value_labels][:type]
  end
end
