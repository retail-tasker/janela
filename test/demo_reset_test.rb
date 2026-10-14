require "test_helper"
require "rake"

# The demo is open for anyone to edit and is put back on the hour, except for
# the Site visits dashboard: it is arranged on purpose, through the agent
# tools, and its numbers are real (ADR 058).
class DemoResetTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("demo:reset")
    ENV["FORCE"] = "1"
    @visits = Janela::Frame.create!(name: PageView::FRAME, columns: 6, gap: 2, owner: customers(:acme))
    @visits.panes.create!(model: "page_views", measure: "views", title: "Kept")
    PageView.record(controller: "docs", action: "show", path: "/docs/agents")
  end

  teardown { ENV.delete("FORCE") }

  def reset
    Rake::Task["demo:reset"].reenable
    capture_io { Rake::Task["demo:reset"].invoke }
  end

  test "the visits dashboard keeps its design through a reset" do
    reset

    frame = Janela::Frame.find_by!(name: PageView::FRAME)
    assert_equal [ 6, 2 ], [ frame.columns, frame.gap ]
    assert_equal [ "Kept" ], frame.panes.map(&:title)
    assert_equal 1, Janela::Frame.where(name: PageView::FRAME).count
  end

  test "and is still owned by whoever the demo's first customer now is" do
    reset

    assert_equal Customer.order(:name).first, Janela::Frame.find_by!(name: PageView::FRAME).owner
  end

  test "the page views are real, so a reset leaves them alone" do
    assert_no_difference -> { PageView.count } do
      reset
    end
  end

  test "every other frame is put back" do
    janela_frames(:orders).update!(name: "Someone's edit")

    reset

    assert_nil Janela::Frame.find_by(name: "Someone's edit")
    assert Janela::Frame.exists?(name: "Revenue at a glance")
  end

  # The seeds used to create these only when there were no frames at all, which
  # stopped being true the moment a reset kept the visits frame.
  test "the original frames are reseeded even though the visits frame is kept" do
    reset

    assert Janela::Frame.exists?(name: "Orders, from the database")
    assert Janela::Frame.exists?(name: "A second tenant's dashboard")
    assert_equal 1, Janela::Frame.where(name: PageView::FRAME).count
  end
end
