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
                unauthenticated_endpoints hardcoded_disallowed_predicates].freeze

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
      def through_dimensions_without_an_allowlist
        janela_models.flat_map do |model|
          model.janela.dimensions.values.select(&:through).filter_map do |dimension|
            association = model.reflect_on_association(dimension.through)
            next unless association

            allowed = association.klass.ransackable_attributes.map(&:to_s)
            next if allowed.include?(dimension.column.to_s)

            Finding.new(severity: :error,
              summary: "#{association.klass} does not allow filtering on #{dimension.column}",
              detail: "  #{model}'s #{dimension.name.inspect} dimension reads it through " \
                      "#{dimension.through.inspect}, and Ransack's allowlist is per class. Add to " \
                      "#{association.klass}:\n" \
                      "    def self.ransackable_attributes(_auth_object = nil) = " \
                      "%w[#{(allowed + [ dimension.column.to_s ]).uniq.join(' ')}]")
          end
        end
      end

      # A filter read from a URL param is runtime state the doctor cannot see,
      # but one written into the host's own Ruby is source like any other
      # identifier this doctor already greps for (ADR 015, ADR 021, ADR 025).
      def hardcoded_disallowed_predicates
        janela_models.flat_map do |model|
          model.janela.dimensions.values.flat_map { |dimension| disallowed_uses(model, dimension) }
        end
      end

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
            Finding.new(severity: :error,
              summary: "#{model} does not allow #{key}",
              detail: "  #{file.relative_path_from(@root)} filters #{model} on #{key}, which Janela now " \
                      "refuses (ADR 025). Allowed here: #{allowed.join(', ')}.")
          end
        end
      end

      # A host that has defined no policy_scope has not said what may be read,
      # and since ADR 032 every dashboard raises rather than answering with
      # every row. Reported so it is found here rather than by a visitor.
      #
      # Where unauthenticated_endpoints has to hedge, because what counts as
      # authentication cannot be determined by reading, this one is exact: the
      # method is defined or it is not, and that is the whole contract.
      def unscoped_reads
        parent = Janela.parent_controller.safe_constantize
        return unless parent
        return if parent.private_method_defined?(:policy_scope) || parent.method_defined?(:policy_scope)

        Finding.new(severity: :error,
          summary: "#{parent} defines no policy_scope, so every pane will raise",
          detail: "  Janela asks your controller what may be read and refuses to guess.\n" \
                  "  Define it on #{parent}:\n" \
                  "    private def policy_scope(model) = model.all\n" \
                  "  That line says every visitor may read every row of every model on a\n" \
                  "  dashboard. If that is not true of this application, return something\n" \
                  "  narrower; docs/multi-tenancy.md has the wiring for the usual libraries.")
      end

      # A host whose policy filters frames by owner, but which never tells
      # Janela what owns a new one, creates frames its own scope then hides.
      # The failure is silent, and a typo in the method name looks the same as
      # not defining it, which is the cost of asking by duck typing (ADR 019).
      def frames_nobody_will_own
        parent = Janela.parent_controller.safe_constantize
        return unless parent&.private_method_defined?(:policy_scope) || parent&.method_defined?(:policy_scope)
        return if parent.private_method_defined?(:janela_frame_owner) || parent.method_defined?(:janela_frame_owner)
        return unless Janela::Frame.table_exists? && scope_filters_frames_by_owner?(parent)

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

      # Asking the policy rather than reading its source: a scope that narrows
      # frames is one that will hide an unowned one.
      def scope_filters_frames_by_owner?(parent)
        scope = parent.allocate.send(:policy_scope, Janela::Frame)
        scope.to_sql.include?("owner")
      rescue StandardError
        false
      end

      # Whether an endpoint is public depends on what the host's controller
      # does, which cannot be determined by reading, so this observes and says
      # so rather than declaring anything safe.
      def unauthenticated_endpoints
        parent = Janela.parent_controller.safe_constantize
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
        ActiveRecord::Base.descendants.select { |model| model.respond_to?(:janela) && model.janela }
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
