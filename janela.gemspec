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
    Janela 0.11.0: no migration. Two things to look for, and if
    neither describes you there is nothing to do.

    Bar charts are drawn in a palette now, not all one colour (ADR 046).
    If you want the old look, UPGRADING.md has the lines that restore it.

    A range a reader sends in q[...], such as q[placed_on_gteq], no
    longer narrows the time pane it names, since clicking a time bucket
    now writes exactly that (ADR 045). A range you fix yourself with
    where: or default_where still does.

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
