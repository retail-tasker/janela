module Janela
  # Reads a host application and reports what it still has to do. Only ever
  # reads and reports: the checks are the install and upgrade traps that
  # experience says actually break a host (ADR 015).
  class Doctor
    # code is the check that produced the finding, set by the runner rather
    # than by each check, so the two can never drift apart.
    Finding = Struct.new(:severity, :summary, :detail, :code, keyword_init: true)

    # Run in this order, and each one names the finding it produces: a host
    # silences a check by that name (ADR 021).
    CHECKS = %i[stale_identifiers unmounted_engine unmigrated_tables unregistered_controllers
                through_dimensions_without_an_allowlist unscoped_reads frames_nobody_will_own
                snapshots_nobody_will_see unauthenticated_endpoints
                hardcoded_disallowed_predicates].freeze

    # Identifiers a previous version of Janela used, and what replaced them.
    RENAMED = {
      "janela--dashboard" => "janela--frame",
      "janela_dashboard" => "janela_frame",
      "janela/dashboard_controller" => "janela/frame_controller",
      "janela/dashboard_controller.js" => "janela/frame_controller.js",
      "Janela::DashboardHelper" => "Janela::FramesHelper",
      "Janela::PanesController" => "Janela::QueriesController",
      "Janela::SnapshotPanesController" => "Janela::SnapshotQueriesController"
    }.freeze

    SEARCHED = %w[app config lib].freeze
    READABLE = %w[.rb .erb .js .erb.html .html.erb .haml .slim .yml].freeze

    def initialize(root)
      @root = Pathname.new(root)
    end

    def report(out)
      findings, silenced = all_findings.partition { |finding| !silenced?(finding) }

      if findings.empty?
        out.puts "Janela: nothing to fix."
      else
        out.puts "Janela found #{findings.size} #{'thing'.pluralize(findings.size)} to look at."
        findings.each do |finding|
          out.puts
          out.puts "#{finding.severity.to_s.upcase} (#{finding.code}): #{finding.summary}"
          out.puts finding.detail
        end
        out.puts
        out.puts "Silence one you have judged a false alarm, in config/initializers/janela.rb:"
        out.puts "  Janela.silenced_checks = %w[#{findings.first.code}]"
        out.puts
        out.puts "Steps for a version upgrade are in UPGRADING.md."
      end

      # Said out loud every run, because a silence nobody remembers is how a
      # real finding goes unread.
      out.puts "Silenced: #{silenced.map(&:code).uniq.join(', ')}." if silenced.any?
      findings.none? { |finding| finding.severity == :error }
    end

    def check
      all_findings.reject { |finding| silenced?(finding) }
    end

    private
      def all_findings
        @all_findings ||= CHECKS.flat_map { |name| findings_from(name) }
      end

      # Struct responds to to_a, so a single finding is wrapped by hand rather
      # than with Array(), which would take it apart into its members.
      def findings_from(name)
        found = send(name)
        found = [ found ] unless found.is_a?(Array)
        found.compact.each { |finding| finding.code = name.to_s.dasherize }
      end

      def silenced?(finding)
        Janela.silenced_checks.map(&:to_s).include?(finding.code)
      end

      def stale_identifiers
        RENAMED.filter_map do |old, new|
          files = source_files.select { |file| file.read.include?(old) }
          next if files.empty?

          Finding.new(severity: :error,
            summary: "#{old} is now #{new}",
            detail: files.map { |file| "  #{file.relative_path_from(@root)}" }.join("\n"))
        end
      end

      def unmounted_engine
        return if engine_mounted?

        Finding.new(severity: :error,
          summary: "Janela::Engine is not mounted",
          detail: "  Add to config/routes.rb, at whatever path suits you:\n" \
                  "    mount Janela::Engine => \"/insights\"")
      end

      # The mount root serves an index of frames, so a host that upgrades
      # without running the migrations finds an exception where its dashboards
      # were. Only a host that mounts the engine needs the tables at all.
      def unmigrated_tables
        return unless engine_mounted?

        missing = [ Janela::Frame, Janela::Pane, Janela::Snapshot ].reject(&:table_exists?).map(&:table_name)
        return if missing.empty?

        Finding.new(severity: :error,
          summary: "#{missing.to_sentence} #{missing.one? ? 'is' : 'are'} missing",
          detail: "  Janela's own pages read these the moment the engine is mounted. Run:\n" \
                  "    bin/rails janela:install:migrations\n" \
                  "    bin/rails db:migrate")
      rescue StandardError
        nil # no database to ask yet
      end

      def engine_mounted?
        Rails.application.routes.routes.any? { |route| route.app.respond_to?(:app) && route.app.app == Janela::Engine }
      end

      def unregistered_controllers
        registered = source_files.any? { |file| file.read.include?("janela--frame") }
        return if registered

        Finding.new(severity: :error,
          summary: "Janela's Stimulus controllers are not registered anywhere",
          detail: "  Without them a dashboard renders but nothing cross-filters, which\n" \
                  "  looks like nothing happening at all. Register both:\n" \
                  "    application.register(\"janela--frame\", JanelaFrameController)\n" \
                  "    application.register(\"janela--chart\", JanelaChartController)")
      end

      # Ransack's allowlist is per class, so a dimension read through an
      # association needs the associated model to allow the attribute too.
      #
      # Grouped by the allowlist that has to be written rather than by the
      # dimension that led here, because that is what the finding is about and
      # there is one of it. Two dimensions reading through the same
      # association used to produce two findings whose suggested lines
      # contradicted each other, so a host pasting both kept the second and
      # silently lost the first; an STI family produced a copy of each per
      # class, since a subclass shares its parent's associations (#44).
      def through_dimensions_without_an_allowlist
        missing_allowlist_entries.map do |klass, entry|
          allowed = klass.ransackable_attributes.map(&:to_s)
          Finding.new(severity: :error,
            summary: "#{klass} does not allow filtering on #{entry[:columns].sort.to_sentence}",
            detail: "  Ransack's allowlist is per class, and these read through an association:\n" \
                    "#{entry[:sources].sort.map { |source| "    #{source}" }.join("\n")}\n" \
                    "  Add to #{klass}:\n" \
                    "    def self.ransackable_attributes(_auth_object = nil) = " \
                    "%w[#{(allowed + entry[:columns].sort).uniq.join(' ')}]")
        end
      end

      # Keyed on the associated class rather than on the declaration, because a
      # subclass may reflect an association its parent does not: two classes
      # sharing a declaration and an association share a fix, and two that do
      # not have a fix each. The source list names declaring classes, so an STI
      # family is one line rather than one per subclass.
      def missing_allowlist_entries
        janela_models.each_with_object({}) do |model, missing|
          model.janela.dimensions.values.select(&:through).each do |dimension|
            association = model.reflect_on_association(dimension.through)
            next unless association
            next if association.klass.ransackable_attributes.map(&:to_s).include?(dimension.column.to_s)

            entry = missing[association.klass] ||= { columns: [], sources: [] }
            entry[:columns] |= [ dimension.column.to_s ]
            entry[:sources] |= [ "#{model.janela.declared_by}'s #{dimension.name.inspect} dimension, " \
                                 "through #{dimension.through.inspect}" ]
          end
        end
      end

      # A filter read from a URL param is runtime state the doctor cannot see,
      # but one written into the host's own Ruby is source like any other
      # identifier this doctor already greps for (ADR 015, ADR 021, ADR 025).
      def hardcoded_disallowed_predicates
        janela_definitions.flat_map do |definition|
          definition.dimensions.values.flat_map { |dimension| disallowed_uses(definition.declared_by, dimension) }
        end
      end

      # One finding per declaration rather than one per class that inherits it.
      # An STI family shares its parent's dimensions (ADR 031), so iterating
      # models multiplied the same finding by the size of the family (#44).
      def janela_definitions
        janela_models.filter_map(&:janela).uniq(&:declared_by)
      end

      # The match is a string in a file, and nothing here establishes that the
      # file filters this model, or filters anything: a comment warning against
      # the predicate reads the same as a call. So the finding says what was
      # seen and admits the limit, and is a warning rather than an error
      # (ADR 021, ADR 035, #51).
      def disallowed_uses(model, dimension)
        pattern = /\b#{Regexp.escape(dimension.ransack_name)}(_\w+)/
        source_files.flat_map do |file|
          content = file.read
          content.scan(pattern).flatten.uniq.filter_map do |candidate|
            predicate = Ransack::Predicate.detect_from_string(candidate.dup)
            next unless predicate
            next if dimension.allowed_predicates.include?(predicate)

            key = "#{dimension.ransack_name}_#{predicate}"
            allowed = dimension.allowed_predicates.map { |p| "#{dimension.ransack_name}_#{p}" }
            Finding.new(severity: :warning,
              summary: "#{model} does not allow #{key}",
              detail: "  #{file.relative_path_from(@root)} mentions #{key}, which Janela refuses on " \
                      "#{model} (ADR 025). Allowed here: #{allowed.join(', ')}.\n" \
                      "  This reads your source for the name and cannot tell which model a match\n" \
                      "  belongs to, so it may be another model's filter, or prose about one.")
          end
        end
      end

      # A host that has defined no policy_scope has not said what may be read,
      # and since ADR 032 every dashboard raises rather than answering with
      # every row. Reported so it is found here rather than by a visitor.
      #
      # ADR 032 called this check exact, on the reasoning that the method is
      # defined or it is not. That was wrong, and ADR 035 supersedes it: Pundit
      # defines policy_scope the moment it is included, whether or not the
      # model has a policy, so for the commonest authorisation library defined
      # and works are different questions. The check makes the call Janela
      # makes rather than reading the method table (#51).
      def unscoped_reads
        parent = parent_controller
        return unless parent
        return undefined_policy_scope(parent) unless answers_policy_scope?(parent)
        return unless Janela::Frame.table_exists? && Janela::Snapshot.table_exists?

        [ Janela::Frame, Janela::Snapshot ].filter_map do |model|
          outcome, answer = ask_for_scope(model)
          next unless outcome == :raised

          Finding.new(severity: :error,
            summary: "#{parent}'s policy_scope raises for #{model}, so every pane will too",
            detail: "  Janela makes this exact call on every dashboard request, and got:\n" \
                    "    #{answer.class}: #{answer.message.to_s.lines.first.to_s.strip.truncate(140)}\n" \
                    "  Janela's own records go through your policy like any other model's, so\n" \
                    "  they need whatever yours need: with Pundit that is a policy class for\n" \
                    "  #{model}. docs/multi-tenancy.md has the wiring.")
        end
      rescue StandardError
        nil # no database to ask yet
      end

      def undefined_policy_scope(parent)
        Finding.new(severity: :error,
          summary: "#{parent} defines no policy_scope, so every pane will raise",
          detail: "  Janela asks your controller what may be read and refuses to guess.\n" \
                  "  Define it on #{parent}:\n" \
                  "    private def policy_scope(model) = model.all\n" \
                  "  That line says every visitor may read every row of every model on a\n" \
                  "  dashboard. If that is not true of this application, return something\n" \
                  "  narrower; docs/multi-tenancy.md has the wiring for the usual libraries.")
      end

      def answers_policy_scope?(parent)
        parent.private_method_defined?(:policy_scope) || parent.method_defined?(:policy_scope)
      end

      # A host whose policy filters frames by owner, but which never tells
      # Janela what owns a new one, creates frames its own scope then hides.
      # The failure is silent, and a typo in the method name looks the same as
      # not defining it, which is the cost of asking by duck typing (ADR 019).
      def frames_nobody_will_own
        parent = parent_controller
        return unless parent && answers_policy_scope?(parent)
        return if parent.private_method_defined?(:janela_frame_owner) || parent.method_defined?(:janela_frame_owner)
        return unless Janela::Frame.table_exists? && owner_filtering(Janela::Frame) == :filtered

        Finding.new(severity: :error,
          summary: "#{parent} scopes frames by owner but defines no janela_frame_owner",
          detail: "  A frame created through Janela's own form would have no owner, and your\n" \
                  "  own scope would then hide it. Define this on #{parent}:\n" \
                  "    def janela_frame_owner\n" \
                  "      Current.account # whatever your policy scope filters frames by\n" \
                  "    end")
      rescue StandardError
        nil # no database or no policy to ask; nothing can be concluded
      end

      # A snapshot with no owner is stored and unreachable to a policy that
      # filters on one: the row is there, a link to it is a 404, and nothing
      # says why. Most often these were taken before the column existed, which
      # is what an upgrade produces.
      #
      # ADR 033 judged this a thinner case than the frame's, because a caller
      # assigns a snapshot's owner in its own Ruby rather than the engine doing
      # it silently, and said it was worth revisiting if it bit. It bit four
      # times in this repository's tests and once on the live demo within an
      # afternoon of the column landing (#49).
      def snapshots_nobody_will_see
        parent = parent_controller
        return unless parent && Janela::Snapshot.table_exists?
        return unless owner_filtering(Janela::Snapshot) == :filtered

        unowned = Janela::Snapshot.where(owner_id: nil).count
        return if unowned.zero?

        Finding.new(severity: :warning,
          summary: "#{unowned} #{'snapshot'.pluralize(unowned)} with no owner, which your policy filters on",
          detail: "  Your policy narrows snapshots by owner, so one with none is stored and\n" \
                  "  unreachable: a link to it answers 404 and nothing says why. Usually these\n" \
                  "  were taken before the owner column existed. Assign an owner to them, or\n" \
                  "  delete them, and pass owner: to Janela::Snapshot.take from now on.")
      rescue StandardError
        nil # no database or no policy to ask; nothing can be concluded
      end

      # Asking the policy rather than reading its source: a scope that narrows
      # an owned record is one that will hide an unowned one. Shared, because
      # a frame and a snapshot are the same question asked of two tables.
      #
      # Three-valued on purpose. Collapsing a raise into false is how both
      # owner checks came to be silent for every host whose policy reaches for
      # the signed in user: a raise is a different fact from a scope that does
      # not filter, and unscoped_reads is the check that reports it (ADR 035).
      def owner_filtering(model)
        outcome, answer = ask_for_scope(model)
        return :raised if outcome == :raised

        answer.to_sql.include?("owner") ? :filtered : :unfiltered
      rescue StandardError
        :raised
      end

      # What Janela's controllers actually inherit. Janela.parent_controller is
      # what a host asked for, and the two differ when it was named too late,
      # which is how a check came to print "Janela's controllers inherit X"
      # about a class that was not in the chain (ADR 035, #38).
      def parent_controller
        Janela::ApplicationController.superclass
      end

      # Asks the host's policy the way a request does. On a controller with no
      # request, session, params and current_user are all unreachable, so a
      # policy that touches any of them raises for a reason that is not the
      # host's fault. Given a request they are empty instead, which is an
      # unauthenticated visitor: the right thing for a check to ask about.
      def ask_for_scope(model)
        controller = parent_controller.allocate
        controller.set_request!(ActionDispatch::TestRequest.create) if controller.respond_to?(:set_request!)
        [ :ok, controller.send(:policy_scope, model) ]
      rescue StandardError => e
        [ :raised, e ]
      end

      # Whether an endpoint is public depends on what the host's controller
      # does, which cannot be determined by reading, so this observes and says
      # so rather than declaring anything safe.
      def unauthenticated_endpoints
        parent = parent_controller
        return unless parent

        filters = parent._process_action_callbacks.map(&:filter).map(&:to_s)
        return if filters.any? { |filter| filter.match?(/authenticat|require_user|require_login|login_required/) }

        Finding.new(severity: :warning,
          summary: "no authentication filter found on #{parent}",
          detail: "  Janela's controllers inherit #{parent}, so they are as public as it is,\n" \
                  "  and this check only reads its filters: if you authenticate another way\n" \
                  "  this is a false alarm. Otherwise see Securing dashboards in the README.")
      end

      def janela_models
        Rails.application.eager_load!
        ActiveRecord::Base.descendants.select { |model| Janela.our_definition(model) }
      rescue StandardError
        []
      end

      def source_files
        @source_files ||= SEARCHED.flat_map do |directory|
          path = @root.join(directory)
          next [] unless path.directory?

          path.glob("**/*").select { |file| file.file? && READABLE.any? { |extension| file.to_s.end_with?(extension) } }
        end
      end
  end
end
