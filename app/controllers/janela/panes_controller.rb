module Janela
  # One pane of a frame, rendered from its row so the row's own title and
  # layout reach the response (ADR 014).
  class PanesController < ApplicationController
    def show
      # Through the host's scope rather than Pane.find, so a frame belonging to
      # another tenant is a 404 (ADR 014).
      frame = janela_scope(Frame).find(params.require(:frame_id))
      @pane = frame.panes.find(params.require(:id))
      @query = @pane.query(filters: filters)
      @result = @query.result(on: janela_scope(@query.model))
    end
  end
end
