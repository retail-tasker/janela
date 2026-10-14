require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_cable/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)
require "janela"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.generators.system_tests = nil

    # The footer's RubyGems and GitHub counts (ADR 060). Off unless an environment
    # turns it on: config.x answers an unset key with a truthy empty object, so a
    # flag with no default is on.
    config.x.fetch_project_stats = false
  end
end
