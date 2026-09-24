require "test_helper"

# The demo installs as an app. Chrome reads the manifest for the name, the
# icons and the screenshots in its install dialog, so a manifest that points
# at an asset that is not there fails quietly rather than loudly.
class PwaTest < ActionDispatch::IntegrationTest
  test "every page links the manifest and the apple touch icon" do
    get root_path

    assert_response :success
    assert_select "link[rel=manifest][href=?]", "/manifest.json"
    assert_select "link[rel=apple-touch-icon]"
    assert_select "meta[name=theme-color]"
  end

  test "the manifest names the app and every image it lists is served" do
    get "/manifest.json"

    assert_response :success
    manifest = JSON.parse(response.body)
    assert_equal "Janela", manifest["name"]
    assert_equal "standalone", manifest["display"]
    assert_equal %w[any maskable], manifest["icons"].map { |icon| icon["purpose"] }.uniq.sort
    assert_equal %w[narrow wide], manifest["screenshots"].map { |shot| shot["form_factor"] }.sort

    (manifest["icons"] + manifest["screenshots"]).each do |image|
      get image["src"]
      assert_response :success, "#{image["src"]} is listed in the manifest but not served"
    end
  end
end
