require "application_system_test_case"

# ADR 050. A class on the markup proves nothing about how big the number is
# drawn, so these read the computed size against the page's own root size.
class ProminenceSystemTest < ApplicationSystemTestCase
  test "a hero number is 3.5 times the root size, a footnote 1.25, and the default stays 2" do
    visit orders_path
    root = page.evaluate_script("parseFloat(getComputedStyle(document.documentElement).fontSize)")

    assert_in_delta 3.5 * root, size_of("Orders"), 0.5
    assert_in_delta 1.25 * root, size_of("Average order"), 0.5
    assert_in_delta 2.0 * root, size_of("Revenue"), 0.5
  end

  private
    def size_of(label)
      wait_for_frames
      page.evaluate_script(<<~JS)
        (() => {
          const value = [...document.querySelectorAll("p.janela-value")].find((p) => p.querySelector(".janela-value-label")?.textContent === "#{label}")
          return value ? parseFloat(getComputedStyle(value.querySelector(".janela-value-number")).fontSize) : null
        })()
      JS
    end
end
