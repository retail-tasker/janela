require "ransack"
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

  # Only models that declare a janela block are addressable over HTTP, so a
  # request parameter can never name an arbitrary class. Names are stored
  # rather than definitions so a reloaded model does not leave a stale class
  # behind in development.
  def self.registry
    @registry ||= Set.new
  end

  def self.register(model)
    registry << model.name
  end

  def self.definition!(name)
    # In development a model is only registered once autoloaded, so a cold
    # lookup loads the app rather than constantizing an unvetted parameter.
    Rails.application.eager_load! unless registry.include?(name)
    raise Error, "#{name.inspect} is not a janela model" unless registry.include?(name)

    name.constantize.janela
  end
end
