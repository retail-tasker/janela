require "test_helper"

# The tools an agent reaches Janela through (ADR 053, #73). Plain Ruby, built
# with the host's own answer to what may be read, so these are tested without
# any MCP library.
class ToolsTest < ActiveSupport::TestCase
  setup do
    @acme = customers(:acme)
    # What a host's policy_scope says, for one tenant: its own frames, and only
    # the paid orders. A different answer per model, because that is what a
    # real scope is.
    @scope = lambda do |model|
      if model == Janela::Frame then model.where(owner: @acme)
      elsif model == Order then model.where(status: "paid", customer_id: @acme.id)
      else model.all
      end
    end
    @tools = Janela::Tools.new(scope: @scope)
    @writer = Janela::Tools.new(scope: @scope, write: true)
  end

  # Believed false: that the refusal in ADR 032 covers anything that reads a
  # model. It lives in the controller. Query#result without on: reads the
  # model's default scope, so a tool that forgot to pass the host's scope showed
  # every order, with no error. Measured on the demo before this was written.
  test "reading a pane goes through the host's scope, not the model's default one" do
    pane = janela_panes(:revenue_by_status_bar)

    unscoped = pane.query.result
    scoped = @tools.call("read_pane", pane_id: pane.id)

    assert_operator unscoped.keys.size, :>, 1, "the fixtures have orders in more than one status"
    assert_equal [ "paid" ], scoped[:values].keys
  end

  test "tools built without a scope are refused when they are built, not when one is called" do
    assert_raises(Janela::Unscoped) { Janela::Tools.new }
    assert_raises(Janela::Unscoped) { Janela::Tools.new(scope: nil) }
    assert_raises(Janela::Unscoped) { Janela::Tools.new(scope: Order) }
  end

  test "a scope that answers with something that is not a relation is refused" do
    tools = Janela::Tools.new(scope: ->(_model) { [] })

    assert_raises(Janela::Unscoped) { tools.call("list_frames") }
  end

  test "each tool says what it is, and the read tools say they only read" do
    tools = @writer.all

    assert tools.all? { |tool| tool.name.present? && tool.description.present? && tool.input_schema.is_a?(Hash) }
    assert_equal %w[describe_vocabulary get_frame list_frames read_pane], tools.select(&:read_only).map(&:name).sort
    assert_equal %w[add_pane move_pane remove_pane update_pane], tools.reject(&:read_only).map(&:name).sort
  end

  test "the write tools are not offered, and not callable, unless asked for" do
    assert_equal %w[describe_vocabulary get_frame list_frames read_pane], @tools.all.map(&:name).sort
    assert_raises(Janela::NotFound) { @tools.call("add_pane", frame_id: janela_frames(:orders).id, model: "orders", measure: "revenue") }
  end

  test "an unknown tool is not found" do
    assert_raises(Janela::NotFound) { @tools.call("drop_tables") }
  end

  test "the vocabulary is what the janela blocks declare, so an agent offers only what can be asked" do
    vocabulary = @tools.call("describe_vocabulary")
    orders = vocabulary[:models].find { |model| model[:name] == "orders" }

    assert_includes orders[:measures], "revenue"
    assert_includes orders[:dimensions].map { |dimension| dimension[:name] }, "status"
    assert orders[:dimensions].find { |dimension| dimension[:name] == "placed_on" }[:time]
    assert_equal Janela.renderers.map(&:to_s).sort, vocabulary[:renderers].sort
    assert_equal Janela.granularities.map(&:to_s).sort, vocabulary[:granularities].sort
  end

  test "frames are listed through the scope" do
    names = @tools.call("list_frames")[:frames].map { |frame| frame[:name] }

    assert_includes names, "Orders"
    assert_not_includes names, "Globex only"
  end

  test "a frame comes with its panes in position order, and one outside the scope is not found" do
    frame = @tools.call("get_frame", frame_id: janela_frames(:orders).id)

    assert_equal frame[:panes].map { |pane| pane[:position] }, frame[:panes].map { |pane| pane[:position] }.sort
    assert_equal "revenue", frame[:panes].first[:measure]
    assert_raises(Janela::NotFound) { @tools.call("get_frame", frame_id: janela_frames(:someone_elses).id) }
  end

  test "a pane in a frame outside the scope cannot be read" do
    other = janela_frames(:someone_elses).panes.create!(model: "orders", measure: "revenue")

    assert_raises(Janela::NotFound) { @tools.call("read_pane", pane_id: other.id) }
  end

  test "a single value reads as a value, and a pane holding words has none to read" do
    total = @tools.call("read_pane", pane_id: janela_panes(:revenue_total).id)
    assert_equal 100.0, total[:value]

    words = janela_frames(:orders).panes.create!(kind: "text", heading: "Note", body: "Words")
    assert_raises(Janela::BadRequest) { @tools.call("read_pane", pane_id: words.id) }
  end

  # A pane ignores a filter on its own dimension, because it shows the
  # alternatives to the reader's selection, so the bound is tested from a pane
  # grouped by something else.
  test "a filter an agent asks for is bounded the way a reader's is" do
    pane = janela_panes(:revenue_by_region)

    assert_raises(Janela::BadRequest) { @tools.call("read_pane", pane_id: pane.id, filters: { "status_cont" => "p" }) }
    assert_equal({ "paid" => 100.0 }, @tools.call("read_pane", pane_id: janela_panes(:revenue_by_status_bar).id, filters: { "channel_eq" => "web" })[:values])
  end

  test "a pane is added with the attributes the README names, and lands last" do
    frame = janela_frames(:orders)
    before = frame.panes.count

    pane = @writer.call("add_pane", frame_id: frame.id, model: "orders", measure: "revenue", dimension: "channel", renderer: "bar", span: 2)

    assert_equal before + 1, frame.panes.count
    assert_equal "channel", pane[:dimension]
    assert_equal before + 1, pane[:position]
  end

  test "a pane that Janela would refuse is refused with its own words" do
    error = assert_raises(Janela::BadRequest) do
      @writer.call("add_pane", frame_id: janela_frames(:orders).id, model: "orders", measure: "nonsense")
    end

    assert_includes error.message, %(Measure "nonsense" is not a measure of Order)
  end

  test "an attribute that is not a pane's is refused rather than dropped" do
    error = assert_raises(Janela::BadRequest) do
      @writer.call("add_pane", frame_id: janela_frames(:orders).id, model: "orders", measure: "revenue", frame_id_override: 9, position: 1)
    end

    assert_includes error.message, "frame_id_override"
    assert_includes error.message, "position"
  end

  test "a pane is updated, and a change that is invalid leaves it as it was" do
    pane = janela_panes(:revenue_by_status_bar)

    @writer.call("update_pane", pane_id: pane.id, title: "Status")
    assert_equal "Status", pane.reload.title

    assert_raises(Janela::BadRequest) { @writer.call("update_pane", pane_id: pane.id, measure: "nonsense") }
    assert_equal "revenue", pane.reload.measure
  end

  test "removing a pane closes the gap it leaves" do
    frame = janela_frames(:orders)
    first = frame.panes.first

    @writer.call("remove_pane", pane_id: first.id)

    assert_equal (1..frame.panes.count).to_a, frame.panes.reload.map(&:position)
  end

  test "a pane moves one place, and the first pane cannot move up" do
    frame = janela_frames(:orders)
    first, second = frame.panes.first(2)

    @writer.call("move_pane", pane_id: second.id, direction: "up")
    assert_equal [ second.id, first.id ], frame.panes.reload.first(2).map(&:id)

    assert_raises(Janela::BadRequest) { @writer.call("move_pane", pane_id: second.id, direction: "sideways") }
  end

  test "nothing outside the scope can be changed" do
    other = janela_frames(:someone_elses).panes.create!(model: "orders", measure: "revenue")

    assert_raises(Janela::NotFound) { @writer.call("update_pane", pane_id: other.id, title: "Mine now") }
    assert_raises(Janela::NotFound) { @writer.call("remove_pane", pane_id: other.id) }
    assert_raises(Janela::NotFound) { @writer.call("add_pane", frame_id: janela_frames(:someone_elses).id, model: "orders", measure: "revenue") }
  end

  test "arguments arrive as strings from a protocol and are read the same" do
    pane = janela_panes(:revenue_by_status_bar)

    assert_equal [ "paid" ], @tools.call("read_pane", "pane_id" => pane.id)[:values].keys
  end
end
