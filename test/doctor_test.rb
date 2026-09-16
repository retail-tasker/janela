require "test_helper"

# Stand ins for a host's own ApplicationController. The checks read the class
# Janela.parent_controller names, so proving them takes a class to name.
class OwnerScopedHost < ActionController::Base
  def policy_scope(model) = model.where(owner_id: 1)
end

class OwnedFrameHost < OwnerScopedHost
  def janela_frame_owner = nil
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

  test "a host that scopes frames by owner but names no owner hook is an error" do
    with_parent_controller "OwnerScopedHost" do
      finding = Janela::Doctor.new(Rails.root).check.find { |f| f.summary.include?("janela_frame_owner") }

      assert_equal :error, finding&.severity, "a frame created here would be hidden by the host's own scope"
      assert_includes finding.detail, "def janela_frame_owner"
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
