class SnapshotsController < ApplicationController
  def show
    @snapshot = Janela::Snapshot.find(params[:id])
  end
end
