require "test_helper"

# #83. Believed: a pane that cannot be drawn fails alone. It does so on the
# engine's own pane page, where the controller rescues a refused request and
# draws a sentence in its place. A frame rendered inline in a host's page runs
# the same queries in the host's own request, with no controller of Janela's
# above them, so the same refusal was a server error for the whole page.
#
# The refusal is right and stays: a filter a model does not declare is refused
# because Ransack would otherwise drop it and show an unfiltered number (ADR
# 025). What changes is how far it reaches. Janela::Unscoped is not rescued
# here: a host that has not scoped is a misconfiguration to be loud about
# (ADR 032), not a pane that cannot be drawn.
class InlinePaneErrorTest < ActionDispatch::IntegrationTest
  SENTENCE = "That request is not allowed on this pane.".freeze
  MISSING = "There is no such pane.".freeze

  # A row saved against a janela block that has since lost the dimension, which
  # is how a frame moved between models leaves a pane behind. The row's own
  # validation would refuse it today, so it is written around it.
  test "a stored pane whose dimension is gone shows a sentence and the rest of the page draws" do
    stale = janela_frames(:orders).panes.create!(model: "orders", measure: "revenue", dimension: "status")
    stale.update_columns(dimension: "no_longer_declared")

    get frame_path(janela_frames(:orders))

    assert_response :success
    # A dimension the model no longer has is a pane that is not there, which is
    # what the engine's pane page says of it too.
    assert_select "turbo-frame##{stale.turbo_frame_id} p.janela-error", MISSING
    assert_select ".janela-value .janela-value-number", "$375.00"
    assert_select "table.janela-pane caption", "Where the money is"
  end

  test "a filter a pane cannot honour is that pane's sentence, not the page's error" do
    get frame_path(janela_frames(:orders), q: { not_a_dimension_eq: "x" })

    assert_response :success
    assert_select "turbo-frame p.janela-error", text: SENTENCE, minimum: 1
  end

  # The detail names models and filter keys, so it goes to the log and the
  # reader sees the plain sentence, as on the pane page.
  test "the reader sees no model or filter name, and the log has them" do
    log = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)

    get frame_path(janela_frames(:orders), q: { not_a_dimension_eq: "x" })

    # The page itself carries the reader's own filter in the frame's data, so
    # what must be clean is the sentence the pane draws, not the whole body.
    errors = css_select("p.janela-error").map(&:text)
    assert_not_empty errors
    assert errors.none? { |text| text.include?("not_a_dimension") || text.include?("Order") }, errors.inspect
    assert_match(/not_a_dimension/, log.string)
  ensure
    Rails.logger = previous
  end

  test "a pane that is not refused is untouched, and a clean frame renders exactly as before" do
    get frame_path(janela_frames(:orders))

    assert_response :success
    assert_select "p.janela-error", false
  end
end
