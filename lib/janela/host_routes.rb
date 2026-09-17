module Janela
  # Route helpers the host application has and the engine does not, forwarded
  # to the host.
  #
  # isolate_namespace points every route helper inside Janela's controllers at
  # the engine's own routes, and a host's ApplicationController runs there,
  # because Janela's controllers inherit it. So an authentication redirect, a
  # rescue_from or an after_action that names one of the host's own routes
  # raises where it would work anywhere else in the application (ADR 022).
  #
  # Only names the engine does not define are forwarded, so the engine's own
  # routes can never be shadowed by a host's. main_app stays the unambiguous
  # way to say either.
  module HostRoutes
    def self.define!(host: Rails.application.routes, engine: Janela::Engine.routes)
      # Routes reload in development, so a name that has gone is removed
      # rather than left behind pointing at nothing.
      instance_methods(false).each { |method| remove_method(method) }

      forwarded(host: host, engine: engine).each do |name|
        define_method(name) do |*args, **options, &block|
          main_app.public_send(name, *args, **options, &block)
        end
      end
    end

    def self.forwarded(host: Rails.application.routes, engine: Janela::Engine.routes)
      # Route loading is lazy, so a call before anything else has drawn the
      # host's routes would otherwise see an empty set rather than an error
      # (issue #37). This does not recurse: define! runs from
      # after_routes_loaded, by which point the reloader has already marked
      # itself loaded.
      Rails.application.reload_routes_unless_loaded
      host.named_routes.helper_names - engine.named_routes.helper_names
    end
  end
end
