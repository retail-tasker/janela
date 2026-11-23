require "test_helper"

# ADR 064. A category pane leaves out the groups under its measure's
# min_rows, which is what a ranking wants, and a pane can ask to list them
# with a dash instead, which is what a table of every group wants. The
# demo's statuses: paid has two orders, pending and refunded one each.
class ShowUnderMinRowsTest < ActionDispatch::IntegrationTest
  def rows
    css_select("table.janela-pane tbody tr").map { |row| row.css("th, td").map { |cell| cell.text.strip } }
  end

  test "by default a pane leaves out the groups under the minimum" do
    get janela.pane_path("orders", "typical_order", "status")

    assert_response :success
    assert_equal [ [ "paid", "$150.00" ] ], rows
  end

  test "the pane URL keeps them, with a dash, after the group that qualified" do
    get janela.pane_path("orders", "typical_order", "status", show_under_min_rows: 1)

    assert_equal [ [ "paid", "$150.00" ], [ "pending", "–" ], [ "refunded", "–" ] ], rows

    get janela.pane_path("orders", "typical_order", "status", show_under_min_rows: "maybe")
    assert_response :bad_request
  end

  test "janela_pane puts it in the URL and the frame id, since kept groups are another answer" do
    plain = ApplicationController.render(inline: "<%= janela_pane Order, :typical_order, by: :status %>")
    kept = ApplicationController.render(inline: "<%= janela_pane Order, :typical_order, by: :status, show_under_min_rows: true %>")

    assert_includes CGI.unescapeHTML(kept), "show_under_min_rows=1"
    assert_not_includes plain, "show_under_min_rows"
    assert_not_equal plain[/<turbo-frame[^>]*\bid="([^"]+)"/, 1], kept[/<turbo-frame[^>]*\bid="([^"]+)"/, 1]
  end

  test "a stored pane carries it from its row, and the form offers it" do
    frame = janela_frames(:orders)
    pane = frame.panes.create!(model: "orders", measure: "typical_order", dimension: "status", show_under_min_rows: true)

    get frame_path(frame)
    assert_select "turbo-frame##{pane.turbo_frame_id} table.janela-pane tbody tr", count: 3

    get janela.edit_frame_pane_path(frame, pane)
    assert_select "input[type=checkbox][name='pane[show_under_min_rows]']"
    patch janela.frame_pane_path(frame, pane), params: { pane: { show_under_min_rows: "0" } }
    assert_not pane.reload.show_under_min_rows
  end

  test "an agent can set it, and it is in the tool's schema" do
    tools = Janela::Tools.new(scope: ->(model) { model.all }, write: true)

    pane = tools.call("add_pane", frame_id: janela_frames(:orders).id, model: "orders", measure: "typical_order", dimension: "status", show_under_min_rows: true)

    assert_equal true, pane[:show_under_min_rows]
    add = Janela::Tools.all(write: true).find { |tool| tool.name == "add_pane" }
    assert_equal "boolean", add.input_schema[:properties][:show_under_min_rows][:type]
  end

  test "the doctor names the column when a stored-frames host skips the migration" do
    hidden = Janela::Pane.column_names - [ "show_under_min_rows" ]
    Janela::Pane.define_singleton_method(:column_names) { hidden }

    finding = Janela::Doctor.new(Rails.root).check.find { |f| f.code == "unmigrated-columns" }

    assert_equal :error, finding&.severity
    assert_includes finding.summary, "show_under_min_rows"
  ensure
    Janela::Pane.singleton_class.send(:remove_method, :column_names)
  end

  test "a single value under the minimum reads as a dash" do
    get janela.pane_path("orders", "typical_order", q: { status_in: [ "pending" ] })

    assert_select ".janela-value", text: /–/
  end
end
