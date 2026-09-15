class FramesController < ApplicationController
  def show
    @frame = policy_scope(Janela::Frame).find(params[:id])
  end
end
