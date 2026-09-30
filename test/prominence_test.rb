require "test_helper"

# ADR 050, #31. Believed (#31): a single value has no typography. It has had
# since #15: 2rem, bold, tabular numerals, so the headline is twice body size.
# What a pane could not do was say it is more or less important than the pane
# beside it, without a host writing CSS against janela-value-number.
class ProminenceTest < ActionDispatch::IntegrationTest
  test "with none set a single value is exactly what it was: no prominence class" do
    get janela.pane_path("orders", "revenue")

    assert_select "p.janela-pane.janela-value"
    assert_select "[class*='janela-prominence']", count: 0
  end

  test "a prominence puts its class on the single value" do
    get janela.pane_path("orders", "revenue", prominence: 3)

    assert_select "p.janela-pane.janela-value.janela-prominence-3 > strong.janela-value-number", "$375.00"
  end

  test "every step from 1 to 3 is a rule the stylesheet defines" do
    css = File.read(Janela::Engine.root.join("app/assets/stylesheets/janela.css"))

    (1..3).each do |step|
      get janela.pane_path("orders", "revenue", prominence: step)
      assert_select "p.janela-value.janela-prominence-#{step}"
      assert_match(/\.janela-prominence-#{step} \.janela-value-number\s*\{/, css)
    end
  end

  # A pane switched between renderers keeps what it had, so a prominence on a
  # renderer with no headline number is ignored and not an error.
  test "a table, a chart and a ring ignore a prominence" do
    [ {}, { as: "bar" }, { as: "doughnut" } ].each do |options|
      get janela.pane_path("orders", "revenue", "status", prominence: 3, **options)

      assert_response :success
      assert_select "[class*='janela-prominence']", count: 0
    end
  end

  test "a prominence that is not a step is a 400 that names nothing internal" do
    [ "0", "4", "hero", "1.5", "-1" ].each do |bad|
      get janela.pane_path("orders", "revenue", prominence: bad)

      assert_response :bad_request, bad
      assert_select "p.janela-error", "That request is not allowed on this pane."
    end
  end

  test "a snapshot pane takes a prominence too" do
    snapshot = Janela::Snapshot.take(name: "September", owner: customers(:acme), taken_at: Time.utc(2026, 9, 15)) do |take|
      take.pane Order, :revenue
    end

    get janela.snapshot_pane_path(snapshot, "orders", "revenue", prominence: 1)

    assert_select "p.janela-value.janela-prominence-1"
  end

  test "a stored pane carries its prominence from the row, so a refresh keeps it" do
    pane = janela_frames(:orders).panes.create!(model: "orders", measure: "revenue", prominence: 3)

    get janela.frame_pane_path(janela_frames(:orders), pane)

    assert_select "p.janela-value.janela-prominence-3"
  end

  test "a stored pane's prominence is one of the three steps, or nothing" do
    frame = janela_frames(:orders)
    pane = ->(prominence) { frame.panes.new(model: "orders", measure: "revenue", prominence: prominence) }

    assert_predicate pane.(nil), :valid?
    (1..3).each { |step| assert_predicate pane.(step), :valid?, step }
    [ 0, 4, -1 ].each { |bad| assert_not_predicate pane.(bad), :valid?, bad }
    assert_equal Janela::Query::PROMINENCES, Janela::Pane::PROMINENCES
  end

  test "the pane form offers a prominence, with Automatic first" do
    get janela.edit_frame_pane_path(janela_frames(:orders), janela_panes(:revenue_total))

    assert_select "select[name='pane[prominence]'] option", count: 4
    assert_select "select[name='pane[prominence]'] option:first-child", text: "Automatic"
  end

  test "the form saves a prominence, and blank clears it" do
    pane = janela_panes(:revenue_total)

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { prominence: "3" } }
    assert_equal 3, pane.reload.prominence

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { prominence: "" } }
    assert_nil pane.reload.prominence
  end

  # It is how a pane is drawn, not which query it is (ADR 029), and it has to
  # be in the URL because the server draws the pane again on every click.
  test "janela_pane puts the prominence in its URL and leaves the frame id alone" do
    get orders_path

    assert_select "turbo-frame#janela_orders_orders[data-janela-src*='prominence=3']"
    assert_select "turbo-frame[data-janela-src*='prominence=']", count: 2
  end
end
