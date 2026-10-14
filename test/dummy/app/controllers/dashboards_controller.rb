class DashboardsController < ApplicationController
  def show
    @snapshot = Janela::Snapshot.order(:taken_at).last
    # By name: the visits frame is kept through a reset, so it is the oldest (ADR 058).
    @frame = Janela::Frame.find_by(name: "Orders, from the database")
    @fixed = params[:status] ? { status_eq: params[:status] } : {}
  end
end
