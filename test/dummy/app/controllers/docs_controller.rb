# Janela's documentation, rendered from the gem's own markdown (ADR 010: the
# guidance ships with the library, so this site reads it rather than restating
# it).
class DocsController < ApplicationController
  def index
    @guides = Doc.guides
    @decisions = Doc.decisions
  end

  def show
    @doc = Doc.find!(params[:slug])
  end
end
