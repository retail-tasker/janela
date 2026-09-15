require "rails/engine"

module Janela
  class Engine < ::Rails::Engine
    isolate_namespace Janela

    initializer "janela.model" do
      ActiveSupport.on_load(:active_record) { extend Janela::Model }
    end

    # isolate_namespace keeps engine helpers out of the host, but the frame
    # helpers are the engine's public API and belong in the host's views.
    initializer "janela.helpers" do
      ActiveSupport.on_load(:action_view) { include Janela::FramesHelper }
    end

    # janela_frame renders the engine's own partials from a host's page, and
    # an engine's views are otherwise only on the lookup path of its own
    # controllers.
    initializer "janela.views" do
      ActiveSupport.on_load(:action_controller) { append_view_path Janela::Engine.root.join("app/views") }
    end

    initializer "janela.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end
  end
end
