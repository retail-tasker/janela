class DashboardsController < ApplicationController
  def show
    @snapshot = Janela::Snapshot.order(:taken_at).last
    @frame = Janela::Frame.order(:id).first
  end
end
