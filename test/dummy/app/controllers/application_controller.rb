class ApplicationController < ActionController::Base
  before_action :set_current_tenant
  before_action :send_the_locked_out_home


  # A stand in for Pundit. Janela asks the host's controller for policy_scope
  # and never reads a model around it, so this is the whole of the wiring a
  # multi tenant host needs: frames belong to a tenant, and everything else is
  # left alone because nothing else in the demo is owned.
  #
  # Private, and with no helper_method, because that is the shape
  # docs/multi-tenancy.md teaches and Pundit's own is protected. The demo
  # published it to the view for a while, which is the only reason #46 went
  # unnoticed: it made the view able to see a method a real host's view
  # cannot.
  private def policy_scope(model)
    case model.name
    # A frame and a snapshot are both owned, so both are filtered the same
    # way. The snapshot half used to be a crude stand in, because the column
    # did not exist until ADR 033.
    when "Janela::Frame", "Janela::Snapshot" then model.where(owner: Current.tenant)
    else model.all
    end
  end

  # Janela asks the host what a new frame belongs to. Without an answer the
  # policy_scope above would hide a frame the moment an analyst created it.
  def janela_frame_owner
    Current.tenant
  end

  private
    # Stands in for an authentication concern: host code that runs inside
    # Janela's controllers, because they inherit this one, and generates a URL
    # from the host's own routes while it is there (ADR 022). ?locked= stands
    # in for a visitor who is not signed in.
    def send_the_locked_out_home
      redirect_to root_path, alert: "Sign in first" if params[:locked]
    end

    # ?tenant= stands in for a session. Alphabetical so the default is stable.
    def set_current_tenant
      Current.tenant = Customer.find_by(id: params[:tenant]) || default_tenant
    end

    def default_tenant
      Customer.order(:name).first
    end
end
