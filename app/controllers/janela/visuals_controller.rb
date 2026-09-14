module Janela
  class VisualsController < ApplicationController
    def show
      @visual = Visual.new(
        definition: Janela.definition!(params.require(:model)),
        measure: params.require(:measure).to_sym,
        dimension: params.require(:by).to_sym,
        renderer: params.fetch(:as, "table"),
        filters: filters
      )

      @result = @visual.result(on: janela_scope(@visual.model))
    end

    private
      def filters
        q = params[:q]
        q.is_a?(ActionController::Parameters) ? q.permit!.to_h : {}
      end
  end
end
