# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-15

First alpha, installed from GitHub for testing in a single host application.

### Added

- `janela do ... end` on an ActiveRecord model declares measures (`sum`, `count`, `average`, `minimum`, `maximum`) and dimensions, including dimensions reached through an association.
- `Model.janela.query(measure, by:, where:, on:)`. Filters are Ransack params; `on:` accepts any relation such as `policy_scope(Model)`.
- Declaring a dimension defines the model's Ransack allowlist. A filter Ransack would silently drop raises instead.
- Rails engine with `janela_dashboard` and `janela_visual` helpers. Each visual is a Turbo Frame; a Stimulus controller cross-filters them by rewriting frame `src`.
- Bar charts via Chart.js (`as: :bar`). A click on a bar is the same filter toggle as a click on a table value.
- The selected value on a visual's own dimension is marked `aria-pressed` on tables and highlighted on charts.
- npm package `@retail-tasker/janela` exposing the two Stimulus controllers for jsbundling hosts; importmap pins for importmap hosts, with a vendored Chart.js.
- Only models that declare a `janela` block are addressable over HTTP.
- ADRs 001 to 004 in `docs/decisions/`, shipped inside the gem.

[0.1.0]: https://github.com/retail-tasker/janela/releases/tag/v0.1.0
