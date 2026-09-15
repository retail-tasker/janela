class FramesController < ApplicationController
  def show
    @frame = Janela::Frame.find(params[:id])
  end
end
