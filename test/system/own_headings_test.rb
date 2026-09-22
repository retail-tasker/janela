require "application_system_test_case"

# A host that writes its own heading above a pane shows the same text twice,
# and deleting Janela's takes the table's accessible name with it: a screen
# reader then lands on a grid of numbers with nothing to say what they
# measure. So the caption is hidden from sight and kept in the tree (#26).
class OwnHeadingsTest < ApplicationSystemTestCase
  test "a caption under janela-own-headings is unseen and still announced" do
    visit vitral_path

    caption = find("#own-headings-example caption", visible: :all)
    assert_equal "Revenue by Status", caption.text(:all), "still the table's accessible name"

    box = page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#own-headings-example caption")
        const rect = el.getBoundingClientRect()
        return { width: Math.round(rect.width), height: Math.round(rect.height) }
      })()
    JS
    assert_operator box["width"], :<=, 1, "hidden from sight"
    assert_operator box["height"], :<=, 1, "hidden from sight"
  end

  test "a caption is drawn normally without the class" do
    visit vitral_path

    box = page.evaluate_script("document.querySelector('#plain-example caption').getBoundingClientRect().width")

    assert_operator box, :>, 1, "an ordinary pane still shows its caption"
  end
end
