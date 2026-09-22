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

# Wired the way a real host is: the policy reaches for the signed in user
# through the session. Nothing in this repository looked like this, and that is
# exactly why the owner checks could be dead for every host that does without a
# test noticing. On a controller with no request `session` is nil, so this
# raises unless the check asks it the way a request would (ADR 035, #51).
class SessionScopedHost < ActionController::Base
  private
    def current_user = session[:user_id] || 1
    def policy_scope(model) = model.where(owner_id: current_user)
end

# What Pundit looks like from Janela's side: policy_scope exists the moment the
# library is included, and raises when the model has no policy of its own. The
# method being defined says nothing about whether calling it works (#51).
class NoPolicyForJanelaHost < ActionController::Base
  private def policy_scope(model) = raise("unable to find scope #{model}Policy::Scope")
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

      assert_equal :warning, finding&.severity, "a grep for a name cannot establish that this file filters that model"
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
    finding = doctor_for(UnscopedHost).check.find { |f| f.code == "unscoped-reads" }

    assert_equal :error, finding&.severity, "every pane raises until this is answered"
    assert_includes finding.detail, "private def policy_scope(model) = model.all"
  end

  # The two authorisation checks cannot both fire: one is about having said
  # nothing, the other about having said something incomplete.
  test "a host that does define policy_scope is not reported as unscoped" do
    assert_nil doctor_for(OwnerScopedHost).check.find { |f| f.code == "unscoped-reads" }
  end

  test "a host that scopes frames by owner but names no owner hook is an error" do
    finding = doctor_for(OwnerScopedHost).check.find { |f| f.summary.include?("janela_frame_owner") }

    assert_equal :error, finding&.severity, "a frame created here would be hidden by the host's own scope"
    assert_includes finding.detail, "def janela_frame_owner"
  end

  # ADR 033 judged this a thinner case than the frame's equivalent, because the
  # caller assigns a snapshot's owner in its own Ruby rather than the engine
  # doing it silently, and said it was worth revisiting if it bit. It bit four
  # times in this repository's own tests and once on the live demo, where a
  # snapshot seeded before the column existed became a 404 the moment the demo
  # started filtering on it (#49).
  test "a snapshot nobody will see is reported when the host filters snapshots by owner" do
    Janela::Snapshot.take(name: "taken before there was an owner") { |take| take.pane Order, :revenue }

    finding = doctor_for(OwnerScopedHost).check.find { |f| f.code == "snapshots-nobody-will-see" }

    assert_equal :warning, finding&.severity, "they are stored and unreachable, not broken"
    assert_includes finding.summary, "1"
  end

  test "a snapshot with an owner is not reported" do
    Janela::Snapshot.take(name: "owned", owner: customers(:acme)) { |take| take.pane Order, :revenue }

    assert_nil doctor_for(OwnerScopedHost).check.find { |f| f.code == "snapshots-nobody-will-see" }
  end

  # A host whose policy does not filter snapshots by owner can see them all,
  # so a nil owner costs it nothing and saying so would be a false alarm.
  test "a nil owner is not reported when the host's policy does not filter on one" do
    Janela::Snapshot.take(name: "taken before there was an owner") { |take| take.pane Order, :revenue }

    assert_nil doctor_for(UnscopedHost).check.find { |f| f.code == "snapshots-nobody-will-see" }
  end

  test "a mounted engine whose tables were never migrated is an error naming the task" do
    without_table :janela_panes do
      finding = Janela::Doctor.new(Rails.root).check.find { |f| f.summary.include?("missing") }

      assert_equal :error, finding&.severity, "the engine's own pages read the table the moment it is mounted"
      assert_includes finding.detail, "janela:install:migrations"
    end
  end

  test "a host that answers who owns a frame is left alone" do
    assert_nil doctor_for(OwnedFrameHost).check.find { |f| f.summary.include?("janela_frame_owner") }
  end

  # Believed false: a check is exact because the method is defined or it is
  # not, which is what ADR 032 said when it shipped unscoped-reads. Pundit
  # defines policy_scope the moment it is included, whether or not the model
  # has a policy, so for the commonest authorisation library "defined" and
  # "works" are different questions. Measured against Pundit 2.5.2: the doctor
  # said nothing while every dashboard request raised (#51).
  test "a host whose policy_scope raises is an error, even though the method is defined" do
    findings = doctor_for(NoPolicyForJanelaHost).check.select { |f| f.code == "unscoped-reads" }

    assert_equal :error, findings.first&.severity, "Janela makes this call on every request"
    assert_includes findings.map(&:summary).join, "Janela::Frame"
    assert_includes findings.map(&:detail).join, "unable to find scope",
      "the host's own exception is quoted, because Janela cannot know what raised it"
  end

  # Believed false: the owner checks work. They call the host's policy_scope on
  # a controller with no request, so a policy that reaches through the session,
  # which is every real one, raised NameError and a blanket rescue read that as
  # "does not filter by owner". Both checks were silent for every such host
  # (ADR 035).
  test "the owner check fires for a host whose policy reaches through the session" do
    finding = doctor_for(SessionScopedHost).check.find { |f| f.summary.include?("janela_frame_owner") }

    assert_equal :error, finding&.severity, "this host does filter frames by owner"
  end

  test "a snapshot nobody will see is found for a session scoped host too" do
    Janela::Snapshot.take(name: "taken before there was an owner") { |take| take.pane Order, :revenue }

    finding = doctor_for(SessionScopedHost).check.find { |f| f.code == "snapshots-nobody-will-see" }

    assert_equal :warning, finding&.severity
  end

  # A raise is reported once, by the check whose question it answers, rather
  # than turning into a wrong conclusion in two others.
  test "a policy that raises is not also reported as failing to filter by owner" do
    summaries = doctor_for(NoPolicyForJanelaHost).check.map(&:summary)

    assert_empty summaries.grep(/janela_frame_owner/)
  end

  # #38: the setting is what a host asked for, the superclass is what Janela
  # uses, and a check that reads the first can print "Janela's controllers
  # inherit X" about a class that is not in the chain.
  test "the checks read what Janela's controllers actually inherit, not the setting" do
    finding = Janela::Doctor.new(Rails.root).check.find { |f| f.code == "unauthenticated-endpoints" }

    assert_includes finding.summary, Janela::ApplicationController.superclass.name
  end

  test "naming a parent controller after the controller has loaded raises rather than being ignored" do
    error = assert_raises Janela::Error do
      Janela.parent_controller = "UnscopedHost"
    end

    assert_includes error.message, Janela::ApplicationController.superclass.name
    assert_includes error.message, "config/initializers"
    assert_equal "ApplicationController", Janela.parent_controller, "the setting is left as it was"
  ensure
    Janela.instance_variable_set(:@parent_controller, "ApplicationController")
  end

  test "naming the controller Janela already inherits is allowed, since nothing is being asked for" do
    assert_nothing_raised { Janela.parent_controller = Janela::ApplicationController.superclass.name }
  end

  # The check greps a host's whole source for a dimension name followed by a
  # predicate, with nothing tying the match to the model that declared the
  # dimension. A host was told an unrelated model's filter was a Janela error
  # (#51), and a comment warning against the predicate reports the same way.
  test "a mention of a disallowed predicate is a warning about a mention, not an error about a filter" do
    in_a_host("app/models/shipment.rb" => "class Shipment\n  def self.late = ransack(status_cont: \"x\")\nend\n") do |root|
      findings = Janela::Doctor.new(root).check.select { |f| f.code == "hardcoded-disallowed-predicates" }

      assert_equal 1, findings.size, "one declaration, one finding, whatever inherits it"
      assert_equal :warning, findings.first.severity, "the check never established that this file filters that model"
      assert_includes findings.first.detail, "mentions"
      assert_not_includes findings.first.detail, "filters Order"
    end
  end

  test "a comment warning against a predicate still reports, but says only what it saw" do
    in_a_host("app/models/note.rb" => "# never filter on status_cont, Janela refuses it\n") do |root|
      finding = Janela::Doctor.new(root).check.find { |f| f.code == "hardcoded-disallowed-predicates" }

      assert_equal :warning, finding&.severity
    end
  end

  # Believed false: one dimension, one finding. Two dimensions reading through
  # the same association produced two findings whose suggested lines
  # contradicted each other, `%w[region]` and `%w[name]`, so a host pasting
  # both ended with the second and had silently lost the first. The finding is
  # about the method that has to be written, and there is one of those (#44).
  test "dimensions reading through one association are one finding, allowing all of them" do
    with_ransackable Customer, [] do
      findings = Janela::Doctor.new(Rails.root).check.select { |f| f.summary.include?("does not allow filtering") }

      assert_equal 1, findings.size, "one allowlist to write, one finding"
      assert_includes findings.first.summary, "name"
      assert_includes findings.first.summary, "region"
      assert_match(/%w\[[^\]]*\bregion\b[^\]]*\bname\b|%w\[[^\]]*\bname\b[^\]]*\bregion\b/, findings.first.detail,
        "the line a host pastes has to allow every column, or applying it loses one")
    end
  end

  # A subclass shares its parent's declaration and its associations, so the
  # fix is the same one line. Five STI classes used to mean five copies of it
  # (#44, ADR 031).
  test "an STI subclass does not repeat the finding its parent's declaration produced" do
    with_ransackable Customer, [] do
      details = Janela::Doctor.new(Rails.root).check
        .select { |f| f.summary.include?("does not allow filtering") }.map(&:detail).join

      assert_includes details, "Order's"
      assert_not_includes details, "WholesaleOrder's", "the subclass inherits the declaration and the fix"
    end
  end

  test "an associated model that already allows the column is left alone" do
    assert_nil Janela::Doctor.new(Rails.root).check.find { |f| f.summary.include?("does not allow filtering") }
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

    # Every check reads Janela::ApplicationController.superclass, which is
    # fixed for the life of the process (#37), so a stand in host is supplied
    # by overriding the one method that answers the question. Assigning
    # Janela.parent_controller is not the way: it never took effect after the
    # controller had loaded, and since ADR 035 it raises rather than pretending.
    def with_ransackable(model, attributes)
      was = model.method(:ransackable_attributes)
      model.define_singleton_method(:ransackable_attributes) { |_ = nil| attributes }
      yield
    ensure
      model.define_singleton_method(:ransackable_attributes, was)
    end

    def doctor_for(host, root = Rails.root)
      Class.new(Janela::Doctor) do
        define_method(:parent_controller) { host }
      end.new(root)
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
