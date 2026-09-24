require "test_helper"

# A host finds its own frame by owner and key (ADR 041, #59). It was believed
# the owner alone was enough, the way dom_id(record) is: it is while an owner
# has one frame, and a tenant has several, so find_by(owner:) returned the
# first frame the tenant ever made rather than the one the page was for.
class FrameKeyTest < ActiveSupport::TestCase
  setup { @acme = customers(:acme) }

  test "an owner's frames are told apart by key, beside the frames analysts made" do
    made_by_an_analyst = janela_frames(:orders)
    assert_equal @acme, made_by_an_analyst.owner

    overview = Janela::Frame.for(@acme, :overview)
    analytics = Janela::Frame.for(@acme, :analytics)

    assert_not_equal made_by_an_analyst, overview
    assert_not_equal overview, analytics
    assert_equal overview, Janela::Frame.for(@acme, :overview)
    assert_equal overview, Janela::Frame.for(@acme, "overview")
  end

  test "the same key belongs to each owner separately" do
    assert_not_equal Janela::Frame.for(@acme, :overview), Janela::Frame.for(customers(:globex), :overview)
  end

  test "a new frame is named after its key, and the block sets it up only when it is created" do
    frame = Janela::Frame.for(@acme, :stock_events)
    assert_equal "Stock events", frame.name

    calls = 0
    named = Janela::Frame.for(@acme, :triage) { |f| calls += 1; f.name = "Triage"; f.columns = 2 }
    assert_equal [ "Triage", 2 ], [ named.name, named.columns ]

    Janela::Frame.for(@acme, :triage) { |f| calls += 1 }
    assert_equal 1, calls
  end

  # The analyst owns everything about a frame but its key, so renaming it
  # cannot detach it from the page that finds it.
  test "renaming a keyed frame leaves it where the host finds it" do
    frame = Janela::Frame.for(@acme, :overview)
    frame.update!(name: "Something an analyst preferred")

    assert_equal frame, Janela::Frame.for(@acme, :overview)
  end

  test "a host with one tenant finds its frames with no owner" do
    frame = Janela::Frame.for(nil, :overview)

    assert_nil frame.owner
    assert_equal frame, Janela::Frame.for(nil, :overview)
  end

  test "one frame per owner and key, enforced by the database" do
    Janela::Frame.for(@acme, :overview)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Janela::Frame.new(name: "Twin", owner: @acme, key: "overview").save!(validate: false)
    end
  end

  test "a key is a short lowercase word, not a name or a path" do
    [ "Overview", "over view", "/overview", "" ].each do |key|
      assert_not Janela::Frame.new(name: "X", owner: @acme, key: key).valid?, key.inspect
    end
    assert Janela::Frame.new(name: "X", owner: @acme, key: nil).valid?
  end
end
