Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=31536000, immutable" }
  config.assume_ssl = true
  config.force_ssl = false
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [ :request_id ]
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  config.hosts = [ ENV["DEMO_HOST"], /\A127\.0\.0\.1\z/, /\Alocalhost\z/ ].compact
  # kamal-proxy health-checks the container by its own hostname.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
