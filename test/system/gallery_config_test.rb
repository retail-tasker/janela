require "application_system_test_case"

# #40: a control beside each gallery pane that rewrites what it draws without
# a page load. Investigating it first showed that rewriting the pane's own
# src and asking Turbo to reload it did not work: Query.turbo_frame_id baked
# the renderer, granularity and limit into the id, so a response for a
# changed selection never carried the id the pane already had, and Turbo had
# nothing to reconcile it against. That is #42, decided in ADR 029: the
# pane is named (`id:`) so its frame never moves, and the response answers to
# whatever frame asked for it. The control can now navigate the frame
# directly, the same way any other link or control would.
class GalleryConfigTest < ApplicationSystemTestCase
  # The fixtures give every dimension three values at most, fewer than any
  # offered limit, so a limit here can never visibly trim a row: this proves
  # the pane went through a genuine round trip for the value chosen, by the
  # limit actually reaching the request Turbo made, rather than a control
  # that changes nothing at all. The frame's own id stays exactly as the
  # page named it throughout, which is the fix (#42, ADR 029): it no longer
  # has to move for Turbo to reconcile the response into it.
  test "changing the limit actually asks for a different query" do
    visit gallery_path

    within("#gallery-bar") do
      named_id = find("turbo-frame", visible: :all)["id"]

      select "5", from: "Rows"

      assert_selector "turbo-frame##{named_id}[complete]", visible: :all
      frame = find("turbo-frame##{named_id}", visible: :all)
      assert_includes frame["data-janela-asked"], "limit=5"
    end
  end

  test "changing the renderer actually redraws the pane as the new chart type" do
    visit gallery_path

    within("#gallery-bar") do
      assert_selector "canvas[data-janela--chart-type-value=bar]"

      select "Line chart", from: "Renderer"

      assert_selector "canvas[data-janela--chart-type-value=line]"
      assert_no_selector "canvas[data-janela--chart-type-value=bar]"
    end
  end

  test "changing the granularity actually redraws the pane with different buckets" do
    visit gallery_path

    within("#gallery-line") do
      before = find("canvas")["data-janela--chart-labels-value"]

      select "Year", from: "Granularity"

      assert_no_selector "canvas[data-janela--chart-labels-value='#{before}']"
    end
  end

  test "the declaration updates to match what is chosen, so it stays copyable" do
    visit gallery_path

    within("#gallery-bar") do
      assert_text "janela_pane Order, :revenue, by: :status"
      assert_no_text "as: :line"

      select "Line chart", from: "Renderer"

      assert_text "janela_pane Order, :revenue, by: :status, as: :line"
    end
  end

  test "a single-value pane offers no configuration, since none of the three parameters change it" do
    visit gallery_path

    within("#gallery-table") do
      assert_no_selector "select"
    end
  end
end
