class DashboardsController < ApplicationController
  def show
    @snapshot = Janela::Snapshot.order(:taken_at).last
    @frame = Janela::Frame.order(:id).first
    @fixed = params[:status] ? { status_eq: params[:status] } : {}
  end
end
