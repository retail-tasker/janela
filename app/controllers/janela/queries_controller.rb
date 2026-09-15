module Janela
  class QueriesController < ApplicationController
    def show
      @query = Query.new(
        definition: Janela.definition!(params.require(:model)),
        measure: params.require(:measure).to_sym,
        dimension: params[:dimension]&.to_sym,
        renderer: params.fetch(:as, "table"),
        granularity: params[:granularity],
        limit: params[:limit],
        filters: filters
      )

      @result = @query.result(on: janela_scope(@query.model))
    end

    private
      def filters
        q = params[:q]
        q.is_a?(ActionController::Parameters) ? q.permit!.to_h : {}
      end
  end
end
