class DashboardsController < ApplicationController
  def show
    @snapshot = Janela::Snapshot.order(:taken_at).last
  end
end
