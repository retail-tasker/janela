class ApplicationController < ActionController::Base
  before_action :set_current_tenant

  # A stand in for Pundit. Janela asks the host's controller for policy_scope
  # and never reads a model around it, so this is the whole of the wiring a
  # multi tenant host needs: frames belong to a tenant, and everything else is
  # left alone because nothing else in the demo is owned.
  def policy_scope(model)
    case model.name
    when "Janela::Frame" then model.where(owner: Current.tenant)
    # A snapshot has no owner column, so a host scopes it by whatever it does
    # have. The demo's rule is crude on purpose: only the first tenant reads
    # what was published.
    when "Janela::Snapshot" then Current.tenant == default_tenant ? model.all : model.none
    else model.all
    end
  end
  helper_method :policy_scope

  # Janela asks the host what a new frame belongs to. Without an answer the
  # policy_scope above would hide a frame the moment an analyst created it.
  def janela_frame_owner
    Current.tenant
  end

  private
    # ?tenant= stands in for a session. Alphabetical so the default is stable.
    def set_current_tenant
      Current.tenant = Customer.find_by(id: params[:tenant]) || default_tenant
    end

    def default_tenant
      Customer.order(:name).first
    end
end
