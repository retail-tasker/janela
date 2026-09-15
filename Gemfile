source "https://rubygems.org"

gemspec

# activesupport 8.1.3.1 calls JSON.parse(json, options) positionally, which
# json 3.0 made keyword-only. Breaks encrypted cookies. Drop when upstream fixes.
gem "json", "< 3"

gem "sqlite3"
gem "propshaft"
gem "puma"
gem "importmap-rails"

group :development, :test do
  gem "rubocop-rails-omakase", require: false
  gem "capybara", require: false
  gem "selenium-webdriver", require: false
end
