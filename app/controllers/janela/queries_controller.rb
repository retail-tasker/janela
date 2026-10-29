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
        sort: params[:sort],
        height: params[:height],
        prominence: params[:prominence],
        value_labels: params[:value_labels],
        companions: params[:companions],
        cumulative: params[:cumulative],
        series: series_params,
        filters: filters,
        fixed: fixed_filters
      )

      @result = @query.result(on: janela_scope(@query.model))
    end

    private
      # A list of hashes, each led by its measure (ADR 062). Anything else in
      # the parameter is handed to the query to be refused with its reason.
      def series_params
        given = params[:series]
        given.is_a?(Array) ? given.map { |each| each.respond_to?(:permit!) ? each.permit!.to_h : each } : given
      end
  end
end
