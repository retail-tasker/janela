require "test_helper"

# The analyst's editing surface: conventional Rails CRUD, no JavaScript, no
# canvas (ADR 012, ADR 014, ADR 018).
class EditingTest < ActionDispatch::IntegrationTest
  setup do
    @frame = janela_frames(:orders)
    @theirs = janela_frames(:someone_elses)
    @globex = customers(:globex)
  end

  test "creating a frame assigns the owner the host names, so it is visible at once" do
    assert_difference -> { Janela::Frame.count }, 1 do
      post janela.frames_path, params: { frame: { name: "New dashboard", columns: 2, gap: 2 } }
    end

    created = Janela::Frame.order(:id).last
    assert_equal customers(:acme), created.owner
    assert_redirected_to janela.edit_frame_path(created)

    follow_redirect!
    assert_response :success
    assert_select "h1", "New dashboard"
  end

  test "a host that defines no owner hook still creates a frame, with no owner" do
    without_owner_hook do
      post janela.frames_path, params: { frame: { name: "Ownerless", columns: 3, gap: 4 } }
    end

    created = Janela::Frame.order(:id).last
    assert_equal "Ownerless", created.name
    assert_nil created.owner

    # And this is why the hook exists: the demo's scope hides what has no
    # owner, so without the hook the analyst's new frame would vanish.
    get janela.frame_path(created)
    assert_response :not_found
  end

  test "a frame with no name is rejected with something readable" do
    assert_no_difference -> { Janela::Frame.count } do
      post janela.frames_path, params: { frame: { name: "", columns: 3, gap: 4 } }
    end

    assert_response :unprocessable_entity
    assert_select ".janela-errors li", /Name/
  end

  test "editing a frame changes its grid" do
    patch janela.frame_path(@frame), params: { frame: { name: "Orders, wider", columns: 4, gap: 6 } }

    assert_redirected_to janela.frame_path(@frame)
    follow_redirect!
    assert_select "div.janela-frame.janela-cols-4.janela-gap-6"
    assert_equal "Orders, wider", @frame.reload.name
  end

  test "a frame's edit page lists its panes in order with the arrangement controls" do
    get janela.edit_frame_path(@frame)

    assert_response :success
    assert_select ".janela-list-row:first-child .janela-list-name", "Revenue"
    assert_select ".janela-list-row:nth-child(2) .janela-list-name", "Where the money is"
    assert_select "form[action=?]", janela.move_down_frame_pane_path(@frame, janela_panes(:revenue_total))
    assert_select "form[action=?]", janela.frame_pane_path(@frame, janela_panes(:revenue_total))
  end

  test "adding a pane is two steps, and the second offers only what the model declares" do
    get janela.new_frame_pane_path(@frame)
    assert_select "select[name=model] option[value=orders]"
    assert_select "select[name='pane[measure]']", false

    get janela.new_frame_pane_path(@frame, model: "orders")
    assert_select "select[name='pane[measure]'] option[value=revenue]"
    assert_select "select[name='pane[measure]'] option[value=profit]", false
    assert_select "select[name='pane[dimension]'] option[value=status]"
    assert_select "select[name='pane[renderer]'] option[value=bar]"
    assert_select "select[name='pane[span]'] option[value='12']"
    assert_select "select[name='pane[limit]'] option[value='10']"
  end

  test "creating a pane puts it last and keeps positions contiguous" do
    assert_difference -> { @frame.panes.count }, 1 do
      post janela.frame_panes_path(@frame), params: {
        pane: { model: "orders", measure: "revenue", dimension: "channel", renderer: "bar", span: 2 }
      }
    end

    assert_redirected_to janela.edit_frame_path(@frame)
    assert_equal (1..5).to_a, @frame.panes.reload.map(&:position)
    assert_equal "channel", @frame.panes.last.dimension
  end

  test "a granularity is offered for a time dimension and not for a categorical one" do
    get janela.edit_frame_pane_path(@frame, janela_panes(:revenue_by_month))
    assert_select "select[name='pane[granularity]'] option[value=week]"

    get janela.edit_frame_pane_path(@frame, janela_panes(:revenue_by_region))
    assert_select "select[name='pane[granularity]']", false
  end

  test "a pane the model cannot answer is rejected on the form rather than saved" do
    assert_no_difference -> { @frame.panes.count } do
      post janela.frame_panes_path(@frame), params: {
        pane: { model: "orders", measure: "revenue", dimension: "status", granularity: "week", span: 1 }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".janela-errors li", /time dimension/
  end

  test "editing a pane changes its width" do
    pane = janela_panes(:revenue_by_region)

    patch janela.frame_pane_path(@frame, pane), params: { pane: { model: "orders", measure: "revenue", dimension: "region", renderer: "table", span: 3 } }

    assert_redirected_to janela.edit_frame_path(@frame)
    assert_equal 3, pane.reload.span

    get janela.frame_path(@frame)
    assert_select "turbo-frame##{pane.turbo_frame_id}.janela-span-3"
  end

  test "a pane moves up and down, and the ends do not move" do
    first, second = @frame.panes.first, @frame.panes.second

    patch janela.move_down_frame_pane_path(@frame, first)
    assert_equal [ second, first ], @frame.panes.reload.first(2)

    patch janela.move_up_frame_pane_path(@frame, first)
    assert_equal [ first, second ], @frame.panes.reload.first(2)

    patch janela.move_up_frame_pane_path(@frame, first)
    assert_response :redirect
    assert_equal (1..4).to_a, @frame.panes.reload.map(&:position)
  end

  test "removing a pane closes the gap it leaves" do
    assert_difference -> { @frame.panes.count }, -1 do
      delete janela.frame_pane_path(@frame, @frame.panes.second)
    end

    assert_equal (1..3).to_a, @frame.panes.reload.map(&:position)
  end

  test "deleting a frame takes its panes and lands on the index" do
    assert_difference -> { Janela::Pane.count }, -@frame.panes.count do
      delete janela.frame_path(@frame)
    end

    assert_redirected_to janela.frames_path
    assert_not Janela::Frame.exists?(@frame.id)
  end

  test "another tenant's frame cannot be edited, updated or deleted" do
    get janela.edit_frame_path(@theirs)
    assert_response :not_found

    patch janela.frame_path(@theirs), params: { frame: { name: "Mine now" } }
    assert_response :not_found
    assert_equal "Globex only", @theirs.reload.name

    delete janela.frame_path(@theirs)
    assert_response :not_found
    assert Janela::Frame.exists?(@theirs.id)
  end

  test "a pane under another tenant's frame cannot be added, moved or removed" do
    theirs = janela_panes(:globex_revenue)

    get janela.new_frame_pane_path(@theirs)
    assert_response :not_found

    post janela.frame_panes_path(@theirs), params: { pane: { model: "orders", measure: "revenue" } }
    assert_response :not_found

    patch janela.move_down_frame_pane_path(@theirs, theirs)
    assert_response :not_found

    delete janela.frame_pane_path(@theirs, theirs)
    assert_response :not_found
    assert Janela::Pane.exists?(theirs.id)
  end

  private
    def without_owner_hook
      ApplicationController.send(:alias_method, :janela_frame_owner_for_test, :janela_frame_owner)
      ApplicationController.send(:remove_method, :janela_frame_owner)
      yield
    ensure
      ApplicationController.send(:alias_method, :janela_frame_owner, :janela_frame_owner_for_test)
      ApplicationController.send(:remove_method, :janela_frame_owner_for_test)
    end
end
