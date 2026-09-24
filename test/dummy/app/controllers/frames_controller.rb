class FramesController < ApplicationController
  def show
    @frame = policy_scope(Janela::Frame).find(params[:id])
    @fixed = params[:status] ? { status_eq: params[:status] } : {}
  end
end
