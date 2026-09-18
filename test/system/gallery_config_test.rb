require "application_system_test_case"

# #40: a control beside each gallery pane that rewrites what it draws without
# a page load. Investigating it first showed that rewriting the pane's own
# src and asking Turbo to reload it does not work: Query.turbo_frame_id bakes
# the renderer, granularity and limit into the id, so a response for a
# changed selection never carries the id the pane already has, and Turbo
# cannot match a response to a request whose id it does not contain. It
# leaves the frame exactly as it was, with no error. Fetching the new pane
# and replacing the existing frame's id and content in one step is what
# actually works, and that is what gallery_config_controller.js does.
class GalleryConfigTest < ApplicationSystemTestCase
  # The fixtures give every dimension three values at most, fewer than any
  # offered limit, so a limit here can never visibly trim a row: this proves
  # the pane went through a genuine round trip for the value chosen, by the
  # id Query.turbo_frame_id only appends when a limit was actually applied,
  # rather than a control that changes nothing at all.
  test "changing the limit actually asks for and draws a different query" do
    visit gallery_path

    within("#gallery-bar") do
      frame = find("turbo-frame", visible: :all)
      unlimited_id = frame["id"]

      select "5", from: "Rows"

      assert_selector "turbo-frame##{unlimited_id}_top5", visible: :all
      assert_no_selector "turbo-frame##{unlimited_id}", visible: :all
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
