require "test_helper"

# ADR 063, #92. A frame hands the reader's filters to every pane unchanged,
# and a pane whose model does not declare a key refuses the request (ADR
# 025). Believed: a pane over a second model in the same frame would simply
# not be narrowed by a click on the first. Measured: it was refused, because
# the refusal cannot tell a typo from another model's dimension. The refusal
# stays the default; a pane may opt out of it.
class IgnoreUnknownFiltersTest < ActionDispatch::IntegrationTest
  SENTENCE = "That request is not allowed on this pane.".freeze

  setup do
    PageView.record(controller: "pages", action: "home", path: "/")
    PageView.record(controller: "docs", action: "show", path: "/docs/theming")
  end

  def views(**options)
    Janela::Query.new(definition: PageView.janela, measure: :views, dimension: :page, **options)
  end

  # The reproduction: a key only the orders model declares.
  test "without the flag a key the model does not declare is refused, as before" do
    assert_raises(Janela::BadRequest) { views(filters: { "status_in" => [ "paid" ] }).result(on: PageView.all) }

    get janela.pane_path("page_views", "views", "page", q: { status_in: [ "paid" ] })
    assert_response :bad_request
    assert_select "p.janela-error", SENTENCE
  end

  test "with the flag the key is dropped and the pane draws as if it were never written" do
    result = views(ignore_unknown_filters: true, filters: { "status_in" => [ "paid" ] }).result(on: PageView.all)

    assert_equal({ "docs#show" => 1, "pages#home" => 1 }, result)
  end

  test "a key the model does declare is still applied beside one that is dropped" do
    result = views(ignore_unknown_filters: true, filters: { "status_in" => [ "paid" ], "path_in" => [ "/" ] }).result(on: PageView.all)

    assert_equal({ "pages#home" => 1 }, result)
  end

  # A real key with a predicate its dimension does not allow is a misuse of
  # that key, not another model's, and stays refused (ADR 025).
  test "a declared key with a disallowed predicate is still refused" do
    assert_raises(Janela::BadRequest) { views(ignore_unknown_filters: true, filters: { "path_matches" => "%" }).result(on: PageView.all) }
  end

  # A host's fixed filter and a frame's default are the host's own words
  # about this pane, not a click on another, and are refused when wrong.
  test "a fixed filter the model cannot apply is still refused" do
    assert_raises(Janela::BadRequest) { views(ignore_unknown_filters: true, fixed: { "status_in" => [ "paid" ] }).result(on: PageView.all) }
  end

  test "the pane's own dimension is set aside either way" do
    result = views(ignore_unknown_filters: true, filters: { "page_in" => [ "pages#home" ], "status_in" => [ "paid" ] }).result(on: PageView.all)

    assert_equal({ "docs#show" => 1, "pages#home" => 1 }, result)
  end

  # Believed: a typo in a real key's predicate is dropped like any stray key.
  # It is a misuse of a real key, so it is refused (ADR 063).
  test "a declared dimension with a misspelt predicate is still refused" do
    assert_raises(Janela::BadRequest) { views(ignore_unknown_filters: true, filters: { "path_inn" => [ "/docs" ] }).result(on: PageView.all) }
  end

  # Believed: starting with a declared name means the key is that dimension's.
  # status_code is another attribute, so a click on status must not keep it.
  test "a key that merely starts with a declared name is not taken for it" do
    kept = PageView.janela.applicable({ "path_in" => [ "/" ], "path_code_in" => [ "x" ] })

    assert_equal [ "path_in" ], kept.keys
  end

  test "the pane URL carries it, and a value that is not a yes or a no is a 400" do
    get janela.pane_path("page_views", "views", "page", ignore_unknown_filters: 1, q: { status_in: [ "paid" ] })
    assert_response :success
    assert_select "table.janela-pane tbody tr", count: 2

    get janela.pane_path("page_views", "views", "page", ignore_unknown_filters: "maybe")
    assert_response :bad_request
  end

  test "a stored pane carries it from the row, so a click on another model's pane leaves it standing" do
    frame = janela_frames(:orders)
    kept = frame.panes.create!(model: "page_views", measure: "views", dimension: "page", ignore_unknown_filters: true)
    refused = frame.panes.create!(model: "page_views", measure: "views", dimension: "page")

    get frame_path(frame, q: { status_in: [ "paid" ] })

    assert_response :success
    assert_select "turbo-frame##{kept.turbo_frame_id} table.janela-pane tbody tr", count: 2
    assert_select "turbo-frame##{refused.turbo_frame_id} p.janela-error", SENTENCE
  end

  test "the pane form offers it as a checkbox and saves it" do
    pane = janela_panes(:revenue_by_region)
    get janela.edit_frame_pane_path(janela_frames(:orders), pane)
    assert_select "input[type=checkbox][name='pane[ignore_unknown_filters]']"

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { ignore_unknown_filters: "1" } }
    assert pane.reload.ignore_unknown_filters

    patch janela.frame_pane_path(janela_frames(:orders), pane), params: { pane: { ignore_unknown_filters: "0" } }
    assert_not pane.reload.ignore_unknown_filters
  end

  # It is how a pane answers a stray key, not which query it is (ADR 029).
  test "janela_pane puts it in its URL only when asked, and leaves the frame id alone" do
    get visits_path

    assert_select "turbo-frame[data-janela-src*='ignore_unknown_filters=']", count: 0
  end

  test "janela_pane with it set puts ignore_unknown_filters=1 in the pane URL, and the frame id is the same" do
    plain = ApplicationController.render(inline: "<%= janela_pane PageView, :views, by: :page %>")
    ignoring = ApplicationController.render(inline: "<%= janela_pane PageView, :views, by: :page, ignore_unknown_filters: true %>")

    assert_includes CGI.unescapeHTML(ignoring), "ignore_unknown_filters=1"
    assert_not_includes plain, "ignore_unknown_filters"
    assert_equal plain[/<turbo-frame[^>]*\bid="([^"]+)"/, 1], ignoring[/<turbo-frame[^>]*\bid="([^"]+)"/, 1]
  end

  test "an agent can set it, and it is in the tool's schema" do
    tools = Janela::Tools.new(scope: ->(model) { model.all }, write: true)

    pane = tools.call("add_pane", frame_id: janela_frames(:orders).id, model: "page_views", measure: "views", dimension: "page", ignore_unknown_filters: true)

    assert_equal true, pane[:ignore_unknown_filters]
    add = Janela::Tools.all(write: true).find { |tool| tool.name == "add_pane" }
    assert_equal "boolean", add.input_schema[:properties][:ignore_unknown_filters][:type]
  end

  test "the doctor names the column when a stored-frames host skips the migration" do
    hidden = Janela::Pane.column_names - [ "ignore_unknown_filters" ]
    Janela::Pane.define_singleton_method(:column_names) { hidden }

    finding = Janela::Doctor.new(Rails.root).check.find { |f| f.code == "unmigrated-columns" }

    assert_equal :error, finding&.severity
    assert_includes finding.summary, "ignore_unknown_filters"
  ensure
    Janela::Pane.singleton_class.send(:remove_method, :column_names)
  end
end
