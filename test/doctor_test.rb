require "test_helper"
require "open3"

# Stand ins for a host's own ApplicationController. The checks read the class
# Janela.parent_controller names, so proving them takes a class to name.
class OwnerScopedHost < ActionController::Base
  def policy_scope(model) = model.where(owner_id: 1)
end

class OwnedFrameHost < OwnerScopedHost
  def janela_frame_owner = nil
end

# A host using a different authorisation library, or none: it has said nothing
# about what may be read, which since ADR 032 is refused rather than answered.
class UnscopedHost < ActionController::Base
end

class DoctorTest < ActiveSupport::TestCase
  teardown { Janela.silenced_checks = [] }

  test "every finding names the check that produced it, so it can be talked about" do
    in_a_host("app/views/thing.html.erb" => "janela_dashboard") do |root|
      finding = Janela::Doctor.new(root).check.find { |f| f.summary.include?("janela_dashboard") }

      assert_equal "stale-identifiers", finding.code
    end
  end

  test "a silenced check is not reported, and the report says so out loud" do
    Janela.silenced_checks = %w[unauthenticated-endpoints]
    out = StringIO.new

    Janela::Doctor.new(Rails.root).report(out)

    assert_empty Janela::Doctor.new(Rails.root).check.select { |f| f.code == "unauthenticated-endpoints" }
    assert_includes out.string, "Silenced: unauthenticated-endpoints."
  end

  test "silencing an error passes the task, since the host has said it knows" do
    in_a_host("app/javascript/application.js" => %(application.register("janela--frame", C)),
              "app/views/thing.html.erb" => "janela_dashboard") do |root|
      assert_not Janela::Doctor.new(root).report(StringIO.new)

      Janela.silenced_checks = [ :"stale-identifiers" ]
      assert Janela::Doctor.new(root).report(StringIO.new)
    end
  end

  test "the dummy application has nothing wrong that Janela can fix" do
    errors = Janela::Doctor.new(Rails.root).check.select { |finding| finding.severity == :error }

    assert_empty errors, errors.map(&:summary).join(", ")
  end

  test "an identifier from a previous version is an error naming its replacement" do
    in_a_host("app/views/thing.html.erb" => %(<button data-action="janela--dashboard#clear">Clear</button>)) do |root|
      finding = Janela::Doctor.new(root).check.find { |f| f.summary.include?("janela--dashboard") }

      assert_equal :error, finding.severity
      assert_includes finding.summary, "janela--frame"
      assert_includes finding.detail, "app/views/thing.html.erb"
    end
  end

  # Believed false: ADR 025 said this could not be found by reading source,
  # because a filter is usually built at runtime from a URL. A filter a host
  # writes in its own Ruby, rather than reading from params, is source like
  # any other identifier the doctor already greps for.
  test "a hardcoded filter using a predicate a dimension no longer allows is found" do
    in_a_host("app/controllers/reports_controller.rb" =>
                "Order.janela.query(:revenue, where: { status_cont: params[:q] })") do |root|
      finding = Janela::Doctor.new(root).check.find { |f| f.summary.include?("status_cont") }

      assert_equal :error, finding&.severity
      assert_equal "hardcoded-disallowed-predicates", finding.code
      assert_includes finding.detail, "app/controllers/reports_controller.rb"
      assert_includes finding.detail, "status_eq"
    end
  end

  test "a hardcoded filter using an allowed predicate is left alone" do
    in_a_host("app/controllers/reports_controller.rb" =>
                "Order.janela.query(:revenue, where: { status_in: params[:q] })") do |root|
      assert_nil Janela::Doctor.new(root).check.find { |f| f.summary.include?("status_in") }
    end
  end

  test "a host that never registers the Stimulus controllers is told what that looks like" do
    in_a_host("app/javascript/application.js" => %(import "@hotwired/turbo-rails")) do |root|
      finding = Janela::Doctor.new(root).check.find { |f| f.summary.include?("not registered") }

      assert_equal :error, finding.severity
      assert_includes finding.detail, "nothing cross-filters"
    end
  end

  test "a warning alone does not fail the task, so a false alarm cannot block CI" do
    in_a_host("app/javascript/application.js" => %(application.register("janela--frame", C))) do |root|
      doctor = Janela::Doctor.new(root)

      assert doctor.report(StringIO.new), "warnings should not fail"
      assert doctor.check.all? { |finding| finding.severity == :warning }, doctor.check.map(&:summary).join(", ")
    end
  end

  test "reporting is false when an error was found, so the task can exit non-zero" do
    in_a_host("app/views/thing.html.erb" => "janela_dashboard") do |root|
      assert_not Janela::Doctor.new(root).report(StringIO.new)
    end
  end

  test "a host that defines no policy_scope at all is an error naming the line to add" do
    with_parent_controller "UnscopedHost" do
      finding = Janela::Doctor.new(Rails.root).check.find { |f| f.code == "unscoped-reads" }

      assert_equal :error, finding&.severity, "every pane raises until this is answered"
      assert_includes finding.detail, "private def policy_scope(model) = model.all"
    end
  end

  # The two authorisation checks cannot both fire: one is about having said
  # nothing, the other about having said something incomplete.
  test "a host that does define policy_scope is not reported as unscoped" do
    with_parent_controller "OwnerScopedHost" do
      assert_nil Janela::Doctor.new(Rails.root).check.find { |f| f.code == "unscoped-reads" }
    end
  end

  test "a host that scopes frames by owner but names no owner hook is an error" do
    with_parent_controller "OwnerScopedHost" do
      finding = Janela::Doctor.new(Rails.root).check.find { |f| f.summary.include?("janela_frame_owner") }

      assert_equal :error, finding&.severity, "a frame created here would be hidden by the host's own scope"
      assert_includes finding.detail, "def janela_frame_owner"
    end
  end

  # ADR 033 judged this a thinner case than the frame's equivalent, because the
  # caller assigns a snapshot's owner in its own Ruby rather than the engine
  # doing it silently, and said it was worth revisiting if it bit. It bit four
  # times in this repository's own tests and once on the live demo, where a
  # snapshot seeded before the column existed became a 404 the moment the demo
  # started filtering on it (#49).
  test "a snapshot nobody will see is reported when the host filters snapshots by owner" do
    Janela::Snapshot.take(name: "taken before there was an owner") { |take| take.pane Order, :revenue }

    with_parent_controller "OwnerScopedHost" do
      finding = Janela::Doctor.new(Rails.root).check.find { |f| f.code == "snapshots-nobody-will-see" }

      assert_equal :warning, finding&.severity, "they are stored and unreachable, not broken"
      assert_includes finding.summary, "1"
    end
  end

  test "a snapshot with an owner is not reported" do
    Janela::Snapshot.take(name: "owned", owner: customers(:acme)) { |take| take.pane Order, :revenue }

    with_parent_controller "OwnerScopedHost" do
      assert_nil Janela::Doctor.new(Rails.root).check.find { |f| f.code == "snapshots-nobody-will-see" }
    end
  end

  # A host whose policy does not filter snapshots by owner can see them all,
  # so a nil owner costs it nothing and saying so would be a false alarm.
  test "a nil owner is not reported when the host's policy does not filter on one" do
    Janela::Snapshot.take(name: "taken before there was an owner") { |take| take.pane Order, :revenue }

    with_parent_controller "UnscopedHost" do
      assert_nil Janela::Doctor.new(Rails.root).check.find { |f| f.code == "snapshots-nobody-will-see" }
    end
  end

  test "a mounted engine whose tables were never migrated is an error naming the task" do
    without_table :janela_panes do
      finding = Janela::Doctor.new(Rails.root).check.find { |f| f.summary.include?("missing") }

      assert_equal :error, finding&.severity, "the engine's own pages read the table the moment it is mounted"
      assert_includes finding.detail, "janela:install:migrations"
    end
  end

  test "a host that answers who owns a frame is left alone" do
    with_parent_controller "OwnedFrameHost" do
      assert_nil Janela::Doctor.new(Rails.root).check.find { |f| f.summary.include?("janela_frame_owner") }
    end
  end

  # Believed false: restoring Janela.parent_controller in an ensure block
  # undoes a swap made for one test. It does not: Janela::ApplicationController
  # resolves Janela.parent_controller once, the first time something eager
  # loads or autoloads it, and stays that way for the rest of the process.
  # Doctor#check eager loads to enumerate models, so if that is the first
  # eager load, it happens while parent_controller points at a stand-in, and
  # every Janela controller inherits the stand-in from then on (issue #37).
  # Whatever ran earlier in this suite's own process may already have eager
  # loaded, so the leak is reproduced in a fresh process instead, where it is
  # deterministic rather than order-dependent.
  test "a doctor check under a swapped parent controller does not leave Janela's controllers inheriting it" do
    script = <<~RUBY
      require "test_helper"

      class StandInHost < ActionController::Base
        def policy_scope(model) = model.where(owner_id: 1)
      end

      Janela.parent_controller = "StandInHost"
      Janela::Doctor.new(Rails.root).check
      Janela.parent_controller = "ApplicationController"

      puts Janela::ApplicationController.superclass
    RUBY

    Dir.mktmpdir do |dir|
      script_path = File.join(dir, "repro.rb")
      File.write(script_path, script)

      out, status = Open3.capture2e({ "CI" => nil }, "ruby", "-Ilib:test:.", script_path,
                                     chdir: File.expand_path("..", __dir__))

      # test_helper pulls in rails/test_help, so minitest/autorun reports its
      # own, separate, empty run after the line this test cares about.
      assert status.success?, out
      assert_equal "ApplicationController", out.lines.first.chomp
    end
  end

  private
    # The check asks the connection rather than a model, so the way to stand
    # in for a host that never ran the migrations is to take the table away.
    def without_table(table)
      connection = ActiveRecord::Base.connection
      connection.rename_table(table, "#{table}_hidden")
      connection.schema_cache.clear!
      yield
    ensure
      connection.rename_table("#{table}_hidden", table)
      connection.schema_cache.clear!
    end

    def with_parent_controller(name)
      was = Janela.parent_controller
      Janela.parent_controller = name
      yield
    ensure
      Janela.parent_controller = was
    end

    # The identifier and registration checks read a host's source, so they are
    # exercised against a planted directory rather than against the dummy.
    def in_a_host(files)
      Dir.mktmpdir do |root|
        files.each do |path, contents|
          full = File.join(root, path)
          FileUtils.mkdir_p(File.dirname(full))
          File.write(full, contents)
        end
        yield Pathname.new(root)
      end
    end
end
