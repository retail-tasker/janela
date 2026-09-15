module Janela
  class ApplicationController < Janela.parent_controller.constantize
    rescue_from Janela::NotFound, with: :janela_not_found
    rescue_from Janela::BadRequest, with: :janela_bad_request

    private
      # Pundit defines policy_scope on the host's ApplicationController, which
      # this inherits from, so authorisation applies without Janela depending
      # on Pundit or being configured.
      def janela_scope(model)
        respond_to?(:policy_scope, true) ? policy_scope(model) : model.all
      end

      def janela_not_found(error)
        janela_error(error, :not_found, "There is no such pane.")
      end

      def janela_bad_request(error)
        janela_error(error, :bad_request, "That request is not allowed on this pane.")
      end

      # The detail names models and filter keys, so it goes to the log; the
      # client sees a plain sentence. A Turbo Frame request gets its frame
      # back so the dashboard shows the sentence where the pane would be.
      def janela_error(error, status, message)
        logger.warn("Janela: #{error.message}")
        frame = request.headers["Turbo-Frame"]
        body = view_context.tag.p(message, class: "janela-pane janela-error")
        body = view_context.turbo_frame_tag(frame) { body } if frame.present?
        render html: body, status: status, layout: frame.blank?
      end
  end
end
