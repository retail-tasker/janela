require "test_helper"

class FrameTest < ActiveSupport::TestCase
  test "a frame needs a name" do
    frame = Janela::Frame.new(name: "")

    assert_not frame.valid?
    assert_includes frame.errors.full_messages.join, "Name"
  end

  test "a frame's grid stays inside the scale the stylesheet enumerates" do
    assert Janela::Frame.new(name: "Orders", columns: 12, gap: 0).valid?
    assert_not Janela::Frame.new(name: "Orders", columns: 13).valid?
    assert_not Janela::Frame.new(name: "Orders", columns: 0).valid?
    assert_not Janela::Frame.new(name: "Orders", gap: 9).valid?
    assert_not Janela::Frame.new(name: "Orders", gap: -1).valid?
  end

  test "a frame defaults to three columns and a gap of four" do
    frame = Janela::Frame.new(name: "Orders")

    assert_equal 3, frame.columns
    assert_equal 4, frame.gap
  end

  test "panes read in position order however they were created" do
    frame = Janela::Frame.create!(name: "Orders")
    frame.panes.create!(model: "orders", measure: "revenue", position: 2)
    frame.panes.create!(model: "orders", measure: "orders", position: 1)

    assert_equal %w[orders revenue], frame.panes.reload.map(&:measure)
  end

  test "deleting a frame takes its panes with it" do
    frame = Janela::Frame.create!(name: "Orders")
    frame.panes.create!(model: "orders", measure: "revenue")

    assert_difference -> { Janela::Pane.count }, -1 do
      frame.destroy
    end
  end

  test "an owner is whatever the host puts there and nothing Janela reads" do
    frame = Janela::Frame.create!(name: "Orders", owner: customers(:acme))

    assert_equal customers(:acme), frame.reload.owner
    assert Janela::Frame.create!(name: "Ownerless").owner.nil?
  end
end
