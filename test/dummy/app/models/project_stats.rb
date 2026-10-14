require "net/http"

# What the footer says about the gem's adoption: its RubyGems downloads and the
# repository's GitHub stars (ADR 060). The server asks, not the browser, so no
# visitor's address reaches either service. The numbers are cached and never
# stored, so they cannot disagree with their source, and a service being down
# costs the page nothing: the footer shows the plain links and the failure is
# remembered for a few minutes so it is not asked again on every view.
class ProjectStats
  GEM_URL = "https://rubygems.org/api/v1/gems/janela.json".freeze
  REPO_URL = "https://api.github.com/repos/retail-tasker/janela".freeze
  FRESH_FOR = 1.hour
  RETRY_AFTER = 5.minutes
  TIMEOUT = 1.5

  # { downloads: 8315, stars: 1 }, with a key missing for a number that could
  # not be had. Nothing at all unless the demo asks for it: the footer is on
  # every page, so fetching in the suite would put the network in every test.
  def self.current
    return {} unless Rails.configuration.x.fetch_project_stats == true

    { downloads: count("downloads", GEM_URL, "downloads"), stars: count("stars", REPO_URL, "stargazers_count") }.compact
  end

  def self.count(name, url, field)
    key = "project_stats/#{name}"
    cached = Rails.cache.read(key)
    return cached[:value] if cached

    value = begin
      Integer(fetch_json(url).fetch(field))
    rescue StandardError => error
      Rails.logger.warn("ProjectStats: #{url}: #{error.class}: #{error.message}")
      nil
    end
    Rails.cache.write(key, { value: value }, expires_in: value ? FRESH_FOR : RETRY_AFTER)
    value
  end

  def self.fetch_json(url)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(uri.request_uri, "Accept" => "application/json", "User-Agent" => "janela-demo")
    end
    raise "answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
