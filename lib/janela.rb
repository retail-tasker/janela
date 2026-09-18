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

  # The stylesheet Janela's own pages load on top of janela.css. Nil means the
  # structural one only, which is what a host that has its own look wants. The
  # gem ships "vitral". A host's own pages are untouched either way: they load
  # whatever that host's layout says (ADR 023).
  mattr_accessor :theme, default: nil

  # Checks janela:doctor should not report, by the name it prints beside each
  # finding. A check that is a false alarm for one application stays a false
  # alarm, and that is a judgement made once at boot, which is what a setting
  # is for (ADR 021).
  mattr_accessor :silenced_checks, default: []

  # A model that declares a janela block is addressable over HTTP, and so is a
  # subclass of one, keyed by the route key that appears in pane URLs (orders,
  # sales_orders). Names are stored rather than classes so a reloaded model
  # leaves nothing stale behind.
  def self.registry
    @registry ||= {}
  end

  def self.register(model)
    registry[model.model_name.route_key] = model.name
  end

  # A subclass registers itself as it is created (ADR 031), so unlike a
  # declaration it is not a host writing a line of code. It never takes a
  # route key another class already holds: a host that gives a subclass its
  # parent's model_name, so the two share a route and a form, would otherwise
  # find the parent's URL answering with a subset of its rows.
  def self.register_subclass(model)
    route_key = model.model_name.route_key
    return if registry.key?(route_key) && registry[route_key] != model.name

    register(model)
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

  # What Janela can draw, so a gallery asks rather than reaching into
  # Janela::Query::RENDERERS, Janela::Dimension::GRANULARITIES or
  # Janela::Pane::OFFERED_LIMITS itself (ADR 027, #39).
  def self.renderers
    Query::RENDERERS
  end

  def self.granularities
    Dimension::GRANULARITIES
  end

  def self.offered_limits
    Pane::OFFERED_LIMITS
  end
end
