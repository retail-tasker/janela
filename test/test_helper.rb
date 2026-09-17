ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"

# Janela::ApplicationController resolves Janela.parent_controller once, the
# first time something eager loads or autoloads it, and stays that way
# whatever a test's ensure block restores afterwards. Eager loading here,
# before any test can swap parent_controller, means that first load has
# already happened against the real setting (issue #37).
Rails.application.eager_load!

ActiveRecord::Migrator.migrations_paths = [ File.expand_path("dummy/db/migrate", __dir__) ]
require "rails/test_help"
require "tmpdir"

ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
ActiveSupport::TestCase.fixtures :all
