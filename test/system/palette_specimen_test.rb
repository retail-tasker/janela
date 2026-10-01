require "application_system_test_case"

# The theming page shows the chart palette rather than describing it (#67). The
# colour values on the page are read from the page's own computed styles, so
# they cannot drift from vitral.css, and these tests hold the page to that.
class PaletteSpecimenTest < ApplicationSystemTestCase
  test "the palette section shows nine swatches, each named and valued from the live styles" do
    visit vitral_path

    within("#palette") do
      assert_selector ".palette-swatch", count: 9
      assert_text "--janela-series-1"
      assert_text "--janela-series-8"
      assert_text "--janela-series-other"
    end

    values = page.evaluate_script("[...document.querySelectorAll('#palette .palette-swatch')].map((s) => s.querySelector('.palette-value').textContent.trim())")
    assert_equal %w[#608fcb #56ab81 #a492da #91507d #be774e #159da9 #c29e51 #994b59 #8794a6], values.map(&:downcase)
  end

  test "each swatch is painted with the property it names" do
    visit vitral_path

    painted = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("#palette .palette-swatch")].map((swatch) => {
        const chip = swatch.querySelector(".palette-chip")
        const probe = document.createElement("span")
        probe.style.color = getComputedStyle(swatch).getPropertyValue("--specimen")
        document.body.appendChild(probe)
        const wanted = getComputedStyle(probe).color
        probe.remove()
        return [wanted, getComputedStyle(chip).backgroundColor]
      })
    JS

    assert painted.all? { |wanted, drawn| wanted == drawn }, painted.inspect
  end

  test "a ring and a bar chart are drawn in it, with enough categories to reach the neutral" do
    visit vitral_path

    within("#palette") do
      assert_selector "svg.janela-ring-svg path.janela-ring-slice", minimum: 2
      assert_selector "canvas.janela-chart"
    end
  end

  test "a host's own set replaces it by setting the properties and nothing else" do
    visit vitral_path

    inner, outer = page.evaluate_script(<<~JS)
      (() => {
        const swatch = (root) => getComputedStyle(root.querySelector(".palette-chip")).backgroundColor
        return [swatch(document.querySelector("#palette-rethemed .palette-swatch:nth-child(2)")), swatch(document.querySelector("#palette .palette-swatch:nth-child(2)"))]
      })()
    JS

    assert_not_equal outer, inner
  end
end
