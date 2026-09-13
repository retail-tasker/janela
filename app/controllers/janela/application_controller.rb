module Janela
  class ApplicationController < Janela.parent_controller.constantize
    private
      # Pundit defines policy_scope on the host's ApplicationController, which
      # this inherits from, so authorisation applies without Janela depending
      # on Pundit or being configured.
      def janela_scope(model)
        respond_to?(:policy_scope, true) ? policy_scope(model) : model.all
      end
  end
end
