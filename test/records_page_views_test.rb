require "test_helper"

# What counts as someone opening a page on the demo: a full HTML load. A pane
# refreshing, a prefetch, a robot or a JSON call is not a visitor, and counting
# them would make the Visits dashboard a picture of the dashboard itself.
class RecordsPageViewsTest < ActionDispatch::IntegrationTest
  test "opening a page records one view of it, without the query string" do
    assert_difference -> { PageView.count }, 1 do
      get orders_path(q: { status_eq: "paid" })
    end

    view = PageView.order(:id).last
    assert_equal "dashboards#show", view.page
    assert_equal "/orders", view.path
    assert_equal Time.zone.today, view.viewed_on
  end

  test "a docs page is told apart by its path as well as its page" do
    get doc_path("agents")

    view = PageView.order(:id).last
    assert_equal "docs#show", view.page
    assert_equal "/docs/agents", view.path
  end

  test "Janela's own pages count, since clicking around them is the demo" do
    get janela.frames_path

    assert_equal "janela/frames#index", PageView.order(:id).last.page
  end

  test "a Turbo Frame request is not a page view" do
    assert_no_difference -> { PageView.count } do
      get orders_path, headers: { "Turbo-Frame" => "some-pane" }
    end
  end

  test "a browser prefetch is not a page view" do
    assert_no_difference -> { PageView.count } do
      get orders_path, headers: { "Sec-Purpose" => "prefetch" }
    end
  end

  test "a robot is not a page view" do
    assert_no_difference -> { PageView.count } do
      get orders_path, headers: { "User-Agent" => "Mozilla/5.0 (compatible; Googlebot/2.1)" }
    end
  end

  test "JSON, a redirect and a missing page are not page views" do
    assert_no_difference -> { PageView.count } do
      get version_path
      get "/docs/naming"
      get "/docs/no-such-doc" rescue nil
    end
  end

  test "a failure to record is reported and never breaks the page" do
    original = PageView.method(:record)
    PageView.define_singleton_method(:record) { |**| raise "boom" }
    reported = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **| reported << error.message }
    Rails.error.subscribe(subscriber)

    get orders_path

    assert_response :success
    assert_equal [ "boom" ], reported
  ensure
    Rails.error.unsubscribe(subscriber)
    PageView.define_singleton_method(:record, original)
  end
end
