module Janela
  # Janela's own pages, so a host can install the gem and navigate the same
  # day (ADR 013). Both actions read through the host's scope rather than
  # Frame.find, so another tenant's frame is a 404 and ids are unguessable in
  # effect if not in form (ADR 014).
  class FramesController < ApplicationController
    def index
      @frames = janela_scope(Frame).includes(:panes).order(:name)
    end

    def show
      @frame = janela_scope(Frame).find(params.require(:id))
    end
  end
end
