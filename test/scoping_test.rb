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
    snapshot = Janela::Snapshot.take(name: "September", taken_at: Time.current) { |take| take.pane Order, :revenue }

    get janela.snapshot_pane_path(snapshot, "orders", "revenue")
    assert_response :success

    get janela.snapshot_pane_path(snapshot, "orders", "revenue", tenant: @globex.id)
    assert_response :not_found
  end
end
