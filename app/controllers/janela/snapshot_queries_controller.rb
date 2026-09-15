module Janela
  # A pane as it was when a snapshot was taken. Filters in the request are
  # ignored: they were fixed at taking (ADR 009).
  class SnapshotQueriesController < ApplicationController
    def show
      # Through the host's scope, so a snapshot its policy hides is a 404
      # rather than a stored result anyone who guesses an id can read (ADR 014).
      snapshot = janela_scope(Snapshot).find(params.require(:snapshot_id))
      @query = Query.new(
        definition: Janela.definition!(params.require(:model)),
        measure: params.require(:measure).to_sym,
        dimension: params[:dimension]&.to_sym,
        renderer: params.fetch(:as, "table"),
        granularity: params[:granularity],
        limit: params[:limit],
        snapshot: snapshot
      )

      @result = @query.result
      render "janela/queries/show"
    end
  end
end
