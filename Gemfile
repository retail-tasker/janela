source "https://rubygems.org"

gemspec

# activesupport 8.1.3.1 calls JSON.parse(json, options) positionally, which
# json 3.0 made keyword-only. Breaks encrypted cookies. Drop when upstream fixes.
gem "json", "< 3"

gem "sqlite3"
gem "propshaft"
gem "puma"
gem "importmap-rails"

# The demo renders the gem's own markdown documentation. Pure Ruby, so the
# demo's image needs no compiler, and deliberately not in the gemspec: a host
# installing janela does not inherit a markdown renderer.
gem "kramdown"
gem "kramdown-parser-gfm"

group :development, :test do
  gem "rubocop-rails-omakase", require: false
  gem "capybara", require: false
  gem "selenium-webdriver", require: false
end

# Live-reloads the demo in a browser tab when a file changes on disk. Demo
# only: the Docker image builds with BUNDLE_WITHOUT="development test", so
# this never reaches the production image or a host installing janela.
group :development do
  gem "hotwire-spark"
end
