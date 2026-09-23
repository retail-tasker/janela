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
    Janela 0.8.0 raises where it used to do nothing. One thing to act on,
    and one to read.

    1. If you set Janela.parent_controller anywhere but an initializer, it
       now raises instead of being ignored in silence. config.to_prepare
       and config.after_initialize are both too late, and the README's own
       layout recipe is a to_prepare block. Until now your dashboards kept
       inheriting whatever was named first, so your authentication and
       policy_scope were not the ones you wrote (ADR 035).

    2. bin/rails janela:doctor reports findings it could not reach before,
       including a Pundit host with no policy for Janela::Frame or
       Janela::Snapshot, which used to pass the doctor and raise on every
       request. Expect things that were always true and never printed.

    Also: the class names on Janela's own pages are no longer public API.
    They are scoped under janela-page and may change in any release. What
    your own markup contains is unchanged and is listed in docs/theming.md.

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
