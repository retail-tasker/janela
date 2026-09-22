require "application_system_test_case"

class CrossFilteringTest < ApplicationSystemTestCase
  test "clicking a value re-scopes the other panes, including the single total" do
    visit orders_path

    within_visual("Revenue by Status") { assert_text "$300.00" }
    within_value("Revenue") { assert_text "$375.00" }

    within_visual("Revenue by Region") { click_on "APAC" }

    within_visual("Revenue by Status") do
      assert_text "$100.00"
      assert_no_text "pending"
    end
    within_value("Revenue") { assert_text "$150.00" }
  end

  test "a visual does not filter itself but marks the selected value" do
    visit orders_path

    within_visual("Revenue by Region") do
      click_on "APAC"
      assert_text "EU"
      assert_text "$225.00"
      assert_selector "button[aria-pressed=true]", text: "APAC"
      assert_selector "button[aria-pressed=false]", text: "EU"
    end
  end

  test "filters from different visuals intersect" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { click_on "paid" }

    within_visual("Orders by Region") do
      assert_selector "td", text: "1"
      assert_no_selector "td", text: "2"
    end
  end

  test "clicking the same value again removes the filter" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { assert_no_text "pending" }

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { assert_text "pending" }
  end

  test "clearing resets every visual" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { assert_text "$100.00" }

    click_on "Clear filters"

    within_visual("Revenue by Status") { assert_text "$300.00" }
  end

  test "filters live in the page URL and survive a reload" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Region") { click_on "APAC" }
    within_visual("Revenue by Status") { assert_text "$100.00" }

    assert_includes current_url, "q%5Bcustomer_region_in%5D%5B%5D=APAC"

    visit current_url
    within_visual("Revenue by Status") { assert_text "$100.00" }
    within_visual("Revenue by Region") { assert_selector "button[aria-pressed=true]", text: "APAC" }

    click_on "Clear filters"
    within_visual("Revenue by Status") { assert_text "$300.00" }
    assert_not_includes current_url, "q%5B"
  end

  test "a dashboard opened from a filtered link renders filtered before any click" do
    visit orders_path(q: { status_eq: "paid" })

    within_visual("Revenue by Region") do
      assert_text "$100.00"
      assert_text "$200.00"
      assert_no_text "$225.00"
    end
    within_value("Revenue") { assert_text "$300.00" }
  end

  test "ctrl clicking adds a value to the selection instead of replacing it" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Status") do
      click_on "paid"
      assert_selector "button[aria-pressed=true]", text: "paid"
      ctrl_click "pending"

      assert_selector "button[aria-pressed=true]", text: "paid"
      assert_selector "button[aria-pressed=true]", text: "pending"
      assert_selector "button[aria-pressed=false]", text: "refunded"
    end

    # EU holds the pending order, so its total only reaches $225.00 when both
    # values are selected. Paid alone is $200.00.
    within_visual("Revenue by Region") { assert_text "$225.00" }
    within_value("Revenue") { assert_text "$325.00" }
  end

  test "ctrl clicking a selected value takes it out and leaves the rest" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Status") do
      click_on "paid"
      assert_selector "button[aria-pressed=true]", text: "paid"
      ctrl_click "pending"
      assert_selector "button[aria-pressed=true]", text: "pending"
      ctrl_click "paid"

      assert_selector "button[aria-pressed=true]", text: "pending"
      assert_selector "button[aria-pressed=false]", text: "paid"
    end

    within_value("Revenue") { assert_text "$25.00" }
  end

  test "a plain click on one of several replaces the whole selection" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Status") do
      click_on "paid"
      assert_selector "button[aria-pressed=true]", text: "paid"
      ctrl_click "pending"
      assert_selector "button[aria-pressed=true]", text: "pending"
      click_on "refunded"

      assert_selector "button[aria-pressed=true]", text: "refunded"
      assert_selector "button[aria-pressed=false]", text: "paid"
    end

    within_value("Revenue") { assert_text "$50.00" }
  end

  test "the selection is in the page URL, so a multi valued filter is a link" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Status") do
      click_on "paid"
      assert_selector "button[aria-pressed=true]", text: "paid"
      ctrl_click "pending"
    end
    within_value("Revenue") { assert_text "$325.00" }

    assert_includes URI.decode_www_form_component(page.current_url), "q[status_in][]=paid"
    assert_includes URI.decode_www_form_component(page.current_url), "q[status_in][]=pending"
  end

  test "escape clears the filters from the keyboard" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Region") { click_on "APAC" }
    within_value("Revenue") { assert_text "$150.00" }

    within_visual("Revenue by Region") { find("button", text: "APAC").send_keys(:escape) }

    within_value("Revenue") { assert_text "$375.00" }
  end

  # The gesture has to be reachable without a mouse, or multi selection is a
  # feature only some people can use (ADR 024). A browser puts the same
  # modifier flags on the click it synthesises from Enter.
  test "ctrl and enter adds to the selection from the keyboard" do
    visit orders_path
    within_visual("Revenue by Status") { assert_text "$300.00" }

    within_visual("Revenue by Status") do
      click_on "paid"
      assert_selector "button[aria-pressed=true]", text: "paid"
      find("button", text: "pending").send_keys([ :control, :enter ])

      assert_selector "button[aria-pressed=true]", text: "paid"
      assert_selector "button[aria-pressed=true]", text: "pending"
    end
  end

  # A lazy pane whose fetch began before a click lands after it. Turbo leaves
  # the newer content in place but resets the frame's src to the URL it
  # fetched, so src stops describing what the pane is showing. Janela kept its
  # record of what it had asked for in that same src, so the next change that
  # happened to match it was skipped and the pane stayed filtered (#33).
  test "a pane reloads after a late response has rewritten its src" do
    visit orders_path
    within_visual("Revenue by Region") { assert_text "$225.00" }

    # One slow load of the region pane, started now so it is still in flight
    # when the click below points that pane somewhere else.
    page.execute_script(<<~JS)
      window.__real = window.fetch
      window.__slowOnce = true
      window.fetch = async (...args) => {
        const url = String(args[0]?.url || args[0])
        const slow = window.__slowOnce && url.includes("/revenue/region")
        if (slow) window.__slowOnce = false
        const response = await window.__real(...args)
        if (slow) await new Promise((resolve) => setTimeout(resolve, 2000))
        return response
      }
      document.querySelector("turbo-frame[src$='/revenue/region']").reload()
    JS

    within_visual("Revenue by Status") { click_on "paid" }

    # The delayed response is deliberately slower than Capybara's default
    # window, and the pane is briefly wrong on its way to being right, so
    # these wait for it to settle rather than for the first thing they see.
    within_visual("Revenue by Region") { assert_text "$200.00", wait: 6 }

    click_on "Clear filters"

    within_visual("Revenue by Region") { assert_text "$225.00", wait: 6 }
  end

  private
    # Capybara has no modifier click, so the modifier is held down around one.
    # Turbo replaces a pane as the previous click lands, so an element found a
    # moment ago may be gone by the time the action runs: find it again rather
    # than fail on a reference to markup that has been swapped out.
    def ctrl_click(label)
      attempts = 0
      begin
        button = find("button", text: label)
        page.driver.browser.action.key_down(:control).click(button.native).key_up(:control).perform
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        raise if (attempts += 1) > 3

        retry
      end
    end

    def within_value(label, &block)
      within(:xpath, "//p[contains(@class, 'janela-value')][span[text()='#{label}']]", &block)
    end

    # A failure in here says only that a selector did not match, which for a
    # pane that is fetched and replaced is not enough to tell a wrong number
    # from a table caught between two responses. #56 was filed on a message
    # that could not distinguish them, so the pane says what state it was in.
    def within_visual(caption, &block)
      within(:xpath, "//table[caption[text()='#{caption}']]", &block)
    rescue Minitest::Assertion, Capybara::ElementNotFound => e
      raise e.class, "#{e.message}\n\n  the pane holding #{caption.inspect} at that moment:\n#{pane_state(caption)}"
    end

    def pane_state(caption)
      page.evaluate_script(<<~JS).map { |line| "    #{line}" }.join("\n")
        (() => {
          const frames = [...document.querySelectorAll("turbo-frame")]
          const mine = frames.find((f) => f.querySelector("caption")?.textContent === #{caption.to_json})
          const report = (f) => [
            `id=${f.id}`,
            `complete=${f.hasAttribute("complete")}`,
            `busy=${f.hasAttribute("busy")}`,
            `rows=${f.querySelectorAll("td").length}`,
            `captions=${f.querySelectorAll("caption").length}`,
            `src=${(f.getAttribute("src") || "").slice(-52)}`,
            `asked=${(f.dataset.janelaAsked || "").slice(-52)}`
          ].join("  ")
          return mine
            ? [ report(mine), `tables on the page with this caption: ${
                frames.filter((f) => f.querySelector("caption")?.textContent === #{caption.to_json}).length}` ]
            : [ "no frame on the page holds that caption", ...frames.map(report) ]
        })()
      JS
    end
end
