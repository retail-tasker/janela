require "ransack"
require "groupdate"
require "turbo-rails"
require "stimulus-rails"

require "janela/version"
require "janela/engine"
require "janela/model"
require "janela/definition"
require "janela/measure"
require "janela/dimension"

module Janela
  class Error < StandardError; end

  # Janela's controllers inherit from the host's, so the host's authentication
  # and authorisation apply to dashboards with no configuration.
  mattr_accessor :parent_controller, default: "ApplicationController"

  # Only models that declare a janela block are addressable over HTTP, keyed by
  # the route key that appears in pane URLs (orders, sales_orders). Names are
  # stored rather than classes so a reloaded model leaves nothing stale behind.
  def self.registry
    @registry ||= {}
  end

  def self.register(model)
    registry[model.model_name.route_key] = model.name
  end

  def self.definition!(route_key)
    # In development a model is only registered once autoloaded, so a cold
    # lookup loads the app rather than constantizing an unvetted parameter.
    Rails.application.eager_load! unless registry.key?(route_key)
    class_name = registry.fetch(route_key) { raise Error, "#{route_key.inspect} is not a janela model" }

    class_name.constantize.janela
  end
end
