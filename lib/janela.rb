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
require "janela/doctor"
require "janela/host_routes"

module Janela
  class Error < StandardError; end
  # Something the request named does not exist: a model, measure, dimension
  # or a pane a snapshot did not freeze. Rendered as 404.
  class NotFound < Error; end
  # Something the request asked for is not allowed here: a renderer, a
  # granularity, a limit or a filter. Rendered as 400.
  class BadRequest < Error; end

  # Janela's controllers inherit from the host's, so the host's authentication
  # and authorisation apply to dashboards with no configuration.
  mattr_accessor :parent_controller, default: "ApplicationController"

  # Checks janela:doctor should not report, by the name it prints beside each
  # finding. A check that is a false alarm for one application stays a false
  # alarm, and that is a judgement made once at boot, which is what a setting
  # is for (ADR 021).
  mattr_accessor :silenced_checks, default: []

  # Only models that declare a janela block are addressable over HTTP, keyed by
  # the route key that appears in pane URLs (orders, sales_orders). Names are
  # stored rather than classes so a reloaded model leaves nothing stale behind.
  def self.registry
    @registry ||= {}
  end

  def self.register(model)
    registry[model.model_name.route_key] = model.name
  end

  # Every model that declares a janela block, for a form that offers a choice
  # of them. Eager loading first, because a model nobody has referenced yet has
  # not registered. A name that no longer resolves is left out rather than
  # raised on: a model renamed or deleted in development leaves its old key
  # here until a restart, and a form offering it would fail to draw at all.
  def self.definitions
    Rails.application.eager_load!
    registry.sort.filter_map { |_route_key, class_name| class_name.safe_constantize&.janela }
  end

  def self.definition!(route_key)
    # In development a model is only registered once autoloaded, so a cold
    # lookup loads the app rather than constantizing an unvetted parameter.
    Rails.application.eager_load! unless registry.key?(route_key)
    class_name = registry.fetch(route_key) { raise NotFound, "#{route_key.inspect} is not a janela model" }

    class_name.constantize.janela
  end
end
