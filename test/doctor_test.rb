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

  test "a host that answers who owns a frame is left alone" do
    with_parent_controller "OwnedFrameHost" do
      assert_nil Janela::Doctor.new(Rails.root).check.find { |f| f.summary.include?("janela_frame_owner") }
    end
  end

  private
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
