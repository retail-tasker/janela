module Janela
  class VisualsController < ApplicationController
    def show
      @visual = Visual.new(
        definition: Janela.definition!(params.require(:model)),
        measure: params.require(:measure).to_sym,
        dimension: params.require(:by).to_sym,
        filters: filters
      )

      @result = @visual.result(on: janela_scope(@visual.model))
    end

    private
      def filters
        params.fetch(:q, {}).permit!.to_h
      end
  end
end
