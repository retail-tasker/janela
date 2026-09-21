require_relative "lib/janela/version"

Gem::Specification.new do |spec|
  spec.name = "janela"
  spec.version = Janela::VERSION
  spec.authors = [ "Jay Killeen", "Vanessa Soares" ]
  spec.email = [ "jay@retailtasker.com.au" ]

  spec.summary = "PowerBI-style dashboards and cross-filtering slicers, native to Rails and ActiveRecord."
  spec.description = "Janela lets you define dashboards directly on your ActiveRecord models and " \
                      "associations. Slicers, cross-filtering charts, and dimension drill-down as " \
                      "first-class Rails citizens, not a bolted-on admin panel. Built on Ruby and " \
                      "Stimulus so it drops onto any Rails application with no separate frontend " \
                      "build step. Dashboards can run live and interactive for internal analysts, " \
                      "or be published as locked, static views for external audiences, from the " \
                      "same underlying definition."
  spec.homepage = "https://github.com/retail-tasker/janela"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  # Set only on a release a host must act on, and removed in the release
  # after, so it stays worth reading (ADR 015).
  spec.post_install_message = <<~MESSAGE
    Janela 0.7.0 stops guessing what may be read. Two things now refuse
    rather than defaulting to every row, and both are quick to answer.

    1. If your ApplicationController defines no policy_scope, every pane
       raises Janela::Unscoped instead of totalling every row. Pundit
       hosts and anyone following docs/multi-tenancy.md: nothing to do.
       Everyone else writes one line (ADR 032).

    2. If you schedule Janela::SnapshotJob, it now needs to be told what
       rows to freeze: pass scope: :model_default, or subclass it and
       override scope_for. A job already on your queue was serialised
       without that argument and will raise when it performs, so drain it
       or re-enqueue (ADR 034).

    If you use snapshots, there is also a migration: janela_snapshots
    gains a nullable owner (ADR 033).

    Steps: UPGRADING.md in this gem, or
    https://github.com/retail-tasker/janela/blob/main/UPGRADING.md

    Then run: bin/rails janela:doctor
  MESSAGE

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,db,lib,docs}/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md", "UPGRADING.md"]
  end
  spec.require_paths = [ "lib" ]

  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "ransack", ">= 4.0"
  spec.add_dependency "groupdate", ">= 6.0"
  spec.add_dependency "turbo-rails", ">= 2.0"
  spec.add_dependency "stimulus-rails", ">= 1.3"
end
