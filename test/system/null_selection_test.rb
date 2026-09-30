require "application_system_test_case"

# ADR 049. The counts the server renders prove nothing about the click, so
# these drive the real gestures and read the frame's filters back.
class NullSelectionTest < ApplicationSystemTestCase
  test "ctrl clicking (none) beside a value selects both, and the other panes count the union" do
    visit orders_path
    within_value("Orders") { assert_text "4" }

    within_channel { click_on "web" }
    within_channel { ctrl_click "(none)" }

    expected = { "channel_in" => [ "web" ], "channel_null" => "1" }
    assert_equal expected, eventually(expected) { frame_filters }
    within_value("Orders") { assert_text "3" }
    within_channel do
      assert_selector "button[aria-pressed=true]", text: "web"
      assert_selector "button[aria-pressed=true]", text: "(none)"
      assert_selector "button[aria-pressed=false]", text: "phone"
    end
  end

  test "ctrl clicking a value beside (none) adds it and leaves (none)" do
    visit orders_path

    within_channel { click_on "(none)" }
    assert_equal({ "channel_null" => "1" }, eventually({ "channel_null" => "1" }) { frame_filters })
    within_channel { ctrl_click "phone" }

    expected = { "channel_in" => [ "phone" ], "channel_null" => "1" }
    assert_equal expected, eventually(expected) { frame_filters }
  end

  test "a plain click replaces the whole selection, the null group included" do
    visit orders_path

    within_channel { click_on "web" }
    within_channel { ctrl_click "(none)" }
    eventually({ "channel_in" => [ "web" ], "channel_null" => "1" }) { frame_filters }
    within_channel { click_on "phone" }

    assert_equal({ "channel_in" => [ "phone" ] }, eventually({ "channel_in" => [ "phone" ] }) { frame_filters })
  end

  test "ctrl clicking (none) again takes it out and leaves the value" do
    visit orders_path

    within_channel { click_on "web" }
    within_channel { ctrl_click "(none)" }
    eventually({ "channel_in" => [ "web" ], "channel_null" => "1" }) { frame_filters }
    within_channel { ctrl_click "(none)" }

    assert_equal({ "channel_in" => [ "web" ] }, eventually({ "channel_in" => [ "web" ] }) { frame_filters })
  end

  private
    def within_channel(&block)
      within(:xpath, "//table[caption[text()='Orders by Channel']]", &block)
    end

    def within_value(label, &block)
      within(:xpath, "//p[contains(@class, 'janela-value')][span[text()='#{label}']]", &block)
    end

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

    def eventually(expected)
      20.times do
        actual = yield
        return actual if actual == expected

        sleep 0.1
      end
      yield
    end

    def frame_filters
      wait_for_frames
      JSON.parse(find("[data-controller='janela--frame']", match: :first)["data-janela--frame-filters-value"] || "{}")
    end
end
