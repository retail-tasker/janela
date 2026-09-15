module Janela
  # A pane as it was when a snapshot was taken. Filters in the request are
  # ignored: they were fixed at taking (ADR 009).
  class SnapshotPanesController < ApplicationController
    def show
      snapshot = Snapshot.find(params.require(:snapshot_id))
      @pane = Pane.new(
        definition: Janela.definition!(params.require(:model)),
        measure: params.require(:measure).to_sym,
        dimension: params[:dimension]&.to_sym,
        renderer: params.fetch(:as, "table"),
        granularity: params[:granularity],
        limit: params[:limit],
        snapshot: snapshot
      )

      @result = @pane.result
      render "janela/panes/show"
    end
  end
end
