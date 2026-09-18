require "application_system_test_case"

# ADR 018 keeps the engine's own pages chart free. The gallery is a host page
# built with janela_pane like any other, so it is exactly where a chart pane
# is expected to draw a chart rather than degrade to its table (#39).
#
# The shell it sits in (the sidebar, the flush-to-the-edges grid, the footer
# inside the content column) is shared with the documentation pages and
# tested once, against every page that uses it, in shell_test.rb.
class GalleryTest < ApplicationSystemTestCase
  test "the bar and line renderers actually draw charts, not tables, on this host page" do
    visit gallery_path

    assert_selector "canvas.janela-chart[data-janela--chart-type-value=bar]"
    assert_selector "canvas.janela-chart[data-janela--chart-type-value=line]"
  end
end
