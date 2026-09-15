class VersionController < ApplicationController
  def show
    render json: { version: Janela::VERSION, commit: ENV.fetch("KAMAL_VERSION") { `git rev-parse HEAD 2>/dev/null`.strip.presence || "dev" } }
  end
end
