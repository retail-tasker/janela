require "test_helper"

# Janela's own pages, at the mount root (ADR 013, ADR 014).
class FramesControllerTest < ActionDispatch::IntegrationTest
  teardown { I18n.reload! }

  test "the index is a card per frame, with its name, its panes and when it changed" do
    janela_frames(:orders).update!(updated_at: 3.days.ago)

    get janela.frames_path

    assert_response :success
    assert_select "h1", "Frames"
    assert_select "a.janela-card[href=?]", janela.frame_path(janela_frames(:orders))
    assert_select ".janela-card-name", "Orders"
    assert_select ".janela-card-meta", /4 panes, changed 3 days ago/
    assert_select ".janela-card-meta", /no panes/
  end

  test "the index says so when the scope returns nothing" do
    Janela::Frame.destroy_all

    get janela.frames_path

    assert_response :success
    assert_select "p.janela-empty", "No frames yet."
    assert_select ".janela-card", false
  end

  test "a frame page renders its panes inline, with no request per pane" do
    get janela.frame_path(janela_frames(:orders))

    assert_response :success
    assert_select "h1", "Orders"
    assert_select "div.janela-frame.janela-cols-3.janela-gap-4"
    assert_select "turbo-frame##{janela_panes(:revenue_total).turbo_frame_id} .janela-value-number", "$375.00"
    assert_select "turbo-frame[src]", false
  end

  # The demo opts every one of Janela's own pages into its own layout (see
  # test/dummy/config/initializers/janela_layout.rb), which is exactly what
  # this test is not about: a host that never touched that setting still
  # gets Janela's own minimal layout, carrying none of a host's assets.
  test "a frame page carries Janela's own stylesheet and none of the host's assets" do
    without_the_demo_layout_override do
      get janela.frame_path(janela_frames(:orders))

      assert_select "link[rel=stylesheet][href*=janela]"
      assert_select "script", false
      assert_select "nav", false
    end
  end

  test "a frame page takes its filters from the page URL" do
    get janela.frame_path(janela_frames(:orders), q: { status_eq: "paid" })

    assert_response :success
    assert_select ".janela-value-number", "$300.00"
  end

  test "the noun is a host's to change in its own locale file" do
    # Reading it first is what loads the gem's own en.yml, which is also the
    # assertion that the shipped default is there to override.
    assert_equal "Frames", Janela::Frame.model_name.human(count: 2)
    I18n.backend.store_translations(:en, activerecord: { models: { "janela/frame": { one: "Dashboard", other: "Dashboards" } } })

    get janela.frames_path

    assert_select "h1", "Dashboards"
  end

  test "frames at the mount root leave the pane grammar alone" do
    get janela.pane_path("orders", "revenue", "status")

    assert_response :success
    assert_select "caption", "Revenue by Status"
  end

  # A host route helper inside the engine was a NameError until ADR 022, which
  # is why these pages had no way back to the application they belong to. The
  # demo opts into its own layout (see
  # test/dummy/config/initializers/janela_layout.rb), which has its own way
  # back to the root, so this test is not about the demo: it is Janela's own
  # exit link, for a host that never opted into anything.
  test "Janela's own pages offer a way back to the host's root" do
    without_the_demo_layout_override do
      get janela.frames_path

      assert_select ".janela-exit a[href=?]", "/"
    end
  end

  test "the editing paths are not swallowed by the greedy pane grammar" do
    frame = janela_frames(:orders)

    get janela.new_frame_path
    assert_select "form input[name='frame[name]']"

    get janela.edit_frame_path(frame)
    assert_select "h1", frame.name

    get janela.new_frame_pane_path(frame)
    assert_select "form select[name=model]"

    get janela.pane_path("orders", "revenue")
    assert_select ".janela-value-label", "Revenue"
  end

  private
    # test/dummy/config/initializers/janela_layout.rb points
    # Janela::FramesController at the demo's own layout by calling the same
    # `layout` class macro Janela::ApplicationController itself calls, which
    # defines two instance methods directly on FramesController -- `_layout`
    # and, because the argument is a Proc, `_layout_from_proc` -- that shadow
    # the ones Janela::ApplicationController defines. Removing both uncovers
    # the shadowed pair underneath, the same way it would for a host that had
    # never called `layout` on the controller at all, and putting the
    # captured methods back afterwards leaves every other test in this file
    # none the wiser.
    def without_the_demo_layout_override
      demo_layout = Janela::FramesController.instance_method(:_layout)
      demo_layout_from_proc = Janela::FramesController.instance_method(:_layout_from_proc)
      Janela::FramesController.send(:remove_method, :_layout, :_layout_from_proc)
      yield
    ensure
      Janela::FramesController.send(:define_method, :_layout, demo_layout)
      Janela::FramesController.send(:define_method, :_layout_from_proc, demo_layout_from_proc)
    end
end
