require "rails/engine"

module Janela
  class Engine < ::Rails::Engine
    isolate_namespace Janela

    initializer "janela.model" do
      ActiveSupport.on_load(:active_record) { extend Janela::Model }
    end
  end
end
