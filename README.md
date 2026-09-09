# Janela

_Working title -- not locked in._

PowerBI-style dashboards and cross-filtering slicers, native to Rails and ActiveRecord. Define a dashboard on your models and associations, get a live, sliceable view for internal use -- or publish the same definition as a locked, static view for an external audience.

## First principle

Janela is a PowerBI-style library built on Ruby and Stimulus, meant to drop onto any Ruby on Rails application. No JS framework, no build step, no separate frontend app -- just a gem you add to an existing Rails app's Gemfile and a set of Stimulus controllers that ship with it.

## Why

Every Rails BI option today is one of:

- **SQL-first** (Blazer) -- powerful, but the query is a black box to your models and associations.
- **Admin-panel-first** (RailsAdmin, ActiveAdmin, Motor Admin, Avo) -- association-aware filtering, but built for CRUD, not for composing multiple charts that filter each other.
- **A dead end for cross-filtering** -- none of the above let clicking one chart re-scope every other chart on the page. That's the actual PowerBI/Tableau slicer experience, and nothing in the Rails ecosystem does it as a first-class citizen.

Janela's bet: the same dashboard definition should serve two audiences without being two systems --

- **Dynamic mode** -- internal analysts get live slicers, cross-filtering, free exploration.
- **Static mode** -- the same dashboard, published, is frozen and locked for client-facing consumption. No slicers, no surprises, opinionated.

## Status

Pre-alpha. Scaffolding only -- no dashboard logic yet. See the open design questions below before expecting any of this to run.

## Open design questions

- **Publish semantics.** Does publishing flip the same record from interactive to static (one source of truth, but an analyst's later edits could silently change what a client sees), or fork a new frozen copy decoupled from the live version (safer, but publish becomes a real fork, not a toggle)? Unresolved -- this is load-bearing for the whole data model.
- **Cross-filtering.** The shared filter-state layer across multiple charts on one page, and a query planner that can intersect filters across divergent association paths without an N+1 explosion.

## Installation

Not yet released. Once it's on RubyGems:

```bash
bundle add janela
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run `rake test` to run the tests. `bin/console` gives you an interactive prompt.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/retail-tasker/janela. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/retail-tasker/janela/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
