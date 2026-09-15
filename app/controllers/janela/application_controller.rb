module Janela
  class ApplicationController < Janela.parent_controller.constantize
    # A frame request needs no layout, since Turbo keeps only the matching
    # frame. A direct request gets Janela's own minimal layout, because a host
    # layout's route helpers cannot resolve inside an isolated engine (ADR 011).
    layout -> { turbo_frame_request? ? false : "janela/application" }

    rescue_from Janela::NotFound, with: :janela_not_found
    # A frame or a pane row the host's scope cannot see is the same answer as a
    # measure that does not exist, and inside a turbo frame it has to be said
    # in the frame rather than by the host's error page.
    rescue_from ActiveRecord::RecordNotFound, with: :janela_not_found
    rescue_from Janela::BadRequest, with: :janela_bad_request

    private
      def filters
        q = params[:q]
        q.is_a?(ActionController::Parameters) ? q.permit!.to_h : {}
      end

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
        body = view_context.tag.p(message, class: "janela-pane janela-error")
        frame = request.headers["Turbo-Frame"]
        body = view_context.turbo_frame_tag(frame) { body } if frame.present?
        render html: body, status: status, layout: frame.blank?
      end
  end
end
