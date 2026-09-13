require "rails/engine"

module Janela
  class Engine < ::Rails::Engine
    isolate_namespace Janela

    initializer "janela.model" do
      ActiveSupport.on_load(:active_record) { extend Janela::Model }
    end

    # isolate_namespace keeps engine helpers out of the host, but the dashboard
    # helpers are the engine's public API and belong in the host's views.
    initializer "janela.helpers" do
      ActiveSupport.on_load(:action_view) { include Janela::DashboardHelper }
    end

    initializer "janela.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end
  end
end
