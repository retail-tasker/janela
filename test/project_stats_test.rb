require "test_helper"

# ADR 060: the footer shows the gem's downloads and the repository's stars,
# fetched by the server and cached, and a service being down costs the page
# nothing.
class ProjectStatsTest < ActionDispatch::IntegrationTest
  setup do
    @was = Rails.configuration.x.fetch_project_stats
    Rails.configuration.x.fetch_project_stats = true
    @store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @fetches = []
    fetches = @fetches
    @real = ProjectStats.method(:fetch_json)
    ProjectStats.define_singleton_method(:fetch_json) do |url|
      fetches << url
      url.include?("rubygems") ? { "downloads" => 8315, "version" => "0.15.0" } : { "stargazers_count" => 1 }
    end
  end

  teardown do
    ProjectStats.define_singleton_method(:fetch_json, @real)
    Rails.cache = @store
    Rails.configuration.x.fetch_project_stats = @was
  end

  test "the footer shows the downloads and the stars, each linking to its source" do
    get root_path

    assert_select "footer a[href='https://rubygems.org/gems/janela']", text: /The gem/
    assert_select "footer .footer-stat", text: "8,315 downloads"
    assert_select "footer .footer-stat", text: "1 star"
  end

  test "stars are pluralised" do
    ProjectStats.define_singleton_method(:fetch_json) { |url| url.include?("rubygems") ? { "downloads" => 1 } : { "stargazers_count" => 42 } }

    get root_path

    assert_select "footer .footer-stat", text: "1 download"
    assert_select "footer .footer-stat", text: "42 stars"
  end

  test "the numbers are fetched once an hour, not once a page" do
    3.times { get root_path }

    assert_equal 2, @fetches.size, "one call to each service"
  end

  test "a service that is down shows the plain links and the page still renders" do
    ProjectStats.define_singleton_method(:fetch_json) { |_url| raise Net::OpenTimeout }

    get root_path

    assert_response :success
    assert_select "footer a[href='https://rubygems.org/gems/janela']"
    assert_select "footer .footer-stat", false
  end

  test "a failure is remembered for a few minutes so a service that is down is not hammered" do
    calls = 0
    ProjectStats.define_singleton_method(:fetch_json) { |_url| calls += 1; raise Net::OpenTimeout }

    3.times { get root_path }

    assert_equal 2, calls, "one attempt at each service, then the failure is cached"
  end

  test "nothing is fetched unless the demo asks for it, so the suite never touches the network" do
    Rails.configuration.x.fetch_project_stats = false

    get root_path

    assert_empty @fetches
    assert_select "footer .footer-stat", false
  end

  test "a reply that is not what was expected is ignored, not shown" do
    ProjectStats.define_singleton_method(:fetch_json) { |_url| { "downloads" => "lots", "stargazers_count" => nil } }

    get root_path

    assert_select "footer .footer-stat", false
  end

  # Rails.configuration.x answers an unset key with an empty options object,
  # which is truthy, so a guard written as `return unless x.flag` was never off.
  # Every page in the suite fetched live for a while before this was written.
  test "a demo that never set the flag fetches nothing, as the test environment does" do
    Rails.configuration.x.fetch_project_stats = ActiveSupport::OrderedOptions.new

    get root_path

    assert_empty @fetches
  end

  test "the test environment itself has the flag off" do
    assert_equal false, @was, "config/application.rb must default it to false, so a test never reaches the network"
  end
end
