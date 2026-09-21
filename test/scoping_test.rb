require "test_helper"

# Janela reads every frame, pane row and snapshot through the host's scope and
# never around it (ADR 014). The dummy stands in for Pundit: frames belong to a
# tenant, so what one tenant cannot see is a 404 rather than a response.
class ScopingTest < ActionDispatch::IntegrationTest
  setup do
    @mine = janela_frames(:orders)
    @theirs = janela_frames(:someone_elses)
    @globex = customers(:globex)
  end

  test "the index lists only the frames the host's scope returns" do
    get janela.frames_path

    assert_response :success
    assert_select ".janela-card-name", "Orders"
    assert_select ".janela-card-name", { text: "Globex only", count: 0 }
  end

  test "the index for another tenant lists theirs and not mine" do
    get janela.frames_path(tenant: @globex.id)

    assert_response :success
    assert_select ".janela-card-name", "Globex only"
    assert_select ".janela-card-name", { text: "Orders", count: 0 }
  end

  test "a frame the host's scope hides is a 404" do
    get janela.frame_path(@theirs)

    assert_response :not_found
  end

  test "a frame the host's scope returns is rendered" do
    get janela.frame_path(@theirs, tenant: @globex.id)

    assert_response :success
    assert_select "h1", "Globex only"
  end

  test "a pane row under someone else's frame is a 404, which is where data would leave" do
    theirs = janela_panes(:globex_revenue)

    get janela.frame_pane_path(@theirs, theirs)
    assert_response :not_found

    get janela.frame_pane_path(@theirs, theirs, tenant: @globex.id)
    assert_response :success
    assert_select ".janela-value-number", "$375.00"
  end

  test "a pane row of mine cannot be read through someone else's frame" do
    get janela.frame_pane_path(@theirs, janela_panes(:revenue_total), tenant: @globex.id)

    assert_response :not_found
  end

  test "a host page renders a frame only for the tenant that owns it" do
    get frame_path(@theirs, tenant: @globex.id)
    assert_response :success

    get frame_path(@theirs)
    assert_response :not_found
  end

  test "a stored pane is read through the host's scope too" do
    snapshot = Janela::Snapshot.take(name: "September", owner: customers(:acme), taken_at: Time.current) { |take| take.pane Order, :revenue }

    get janela.snapshot_pane_path(snapshot, "orders", "revenue")
    assert_response :success

    get janela.snapshot_pane_path(snapshot, "orders", "revenue", tenant: @globex.id)
    assert_response :not_found
  end

  # A host writes policy_scope as a private controller method: that is the
  # shape docs/multi-tenancy.md teaches, and Pundit's own is protected, so
  # neither is visible to a view. The helper that scopes a frame rendered in
  # a host's own page asked the view whether the method existed, where the
  # engine's controllers ask themselves, so a host following the guide was
  # scoped on Janela's pages and unscoped on its own. The demo hid it by
  # publishing policy_scope to the view, which the guide never asks for (#46).
  test "a frame in a host's own page is scoped by a private controller method" do
    hiding_orders do
      get frame_path(@mine)

      assert_response :success
      assert_select ".janela-value-number", "$0.00"
    end
  end

  # ADR 032. A host that has defined no policy_scope has not said what may be
  # read, and Janela used to answer anyway with every row: a 200 carrying
  # numbers the reader may have no right to, with nothing in the log. Both
  # paths refuse now, because the fallback was in two places and a host is
  # only as scoped as its weakest one.
  test "a host that has said nothing about scope is refused on Janela's own pages" do
    without_any_scope do
      assert_raises(Janela::Unscoped) { get janela.frames_path }
    end
  end

  test "the refusal names the method to define, because it is a setup mistake" do
    without_any_scope do
      error = assert_raises(Janela::Unscoped) { get janela.frames_path }

      assert_match "policy_scope", error.message
      assert_match "ApplicationController", error.message
    end
  end

  private
    # A host using a different authorisation library, or none, defines nothing
    # at all. That is the state this refuses.
    def without_any_scope
      original = ApplicationController.instance_method(:policy_scope)
      ApplicationController.send(:remove_method, :policy_scope)
      yield
    ensure
      ApplicationController.send(:define_method, :policy_scope, original)
      ApplicationController.send(:private, :policy_scope)
    end

    # The demo leaves Order alone, so a scope that narrows it has to be put
    # there for the length of one request, private and unpublished to the
    # view exactly as a host's own is.
    def hiding_orders
      original = ApplicationController.instance_method(:policy_scope)
      ApplicationController.class_eval do
        private def policy_scope(model)
          model.name == "Order" ? model.none : model.all
        end
      end
      yield
    ensure
      ApplicationController.send(:define_method, :policy_scope, original)
      ApplicationController.send(:private, :policy_scope)
    end
end
