# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Janela::Frame.for(owner, key)`, so your code finds a frame it keeps for one of its pages: `Janela::Frame.for(account, :overview)`, `Janela::Frame.for(queue, :analytics)`. Finding by owner alone worked while an owner had one frame, and a tenant has several, so `find_by(owner: account)` returned the first frame the tenant ever made rather than the one the page was for. A frame now carries a nullable `key`, unique per owner in the database, which you set and nothing else reads: never in a URL or the engine's forms, so an analyst can rename a keyed frame without detaching it. The frame is created on first use, named after its key unless the block you pass says otherwise. Not the slug ADR 013 turned down, and the ADR says why. Needs a migration; see `UPGRADING.md` (ADR 041, #59).
- **A pane can hold words.** A stored frame rendered its panes and nothing else, and a pane had to name a measure, so the analyst who owns a frame could choose every number on it and label none of them. A pane now has a `kind`: `query`, today's pane and the default, `text`, a heading, a body and a link the analyst writes, and `partial`, a partial you wrote under `app/views/janela_content/` that the analyst places by name and hands the same three strings. What an analyst writes is escaped, a link must be a path on your own site, and no HTML, Markdown or template is ever stored in a row, so the promise of ADR 012 still holds: an analyst arranges and writes words, and only code writes markup. Rendered as `div.janela-pane.janela-content`, with `janela-content-heading` on a text pane's heading, both added to the theming contract. Needs a migration; see `UPGRADING.md` (ADR 039, #58).
- `janela_frame` takes `where:`, a filter the host fixes for one render: `janela_frame @frame, where: { queue_id_eq: @queue.id }`, or the same on the block form. It is for one frame shown on every record's page, narrowed to that record. Until now the only way was the page URL's `q[...]`, and that is the reader's: Clear filters, Escape, and a click on the same dimension all removed it, and the page then showed every record the reader could see under one record's heading. `where:` travels in each pane's URL as `where[...]`, which nothing the reader does touches, is applied before the reader's own filters so theirs can only narrow inside it, and is bounded exactly as `q[...]` is. A pane repointed with `janela--frame:repoint` keeps it. It is a view filter and not a permission: keep rows out of a reader's reach in `policy_scope` (ADR 040, #57).

### Changed

- The roadmap is called **Vista**, and the half of it beyond 1.0 is **Horizonte**. `docs/roadmap.md` keeps its path and its URL, so every link into it still resolves; what changed is the page's title, the demo's navigation, and `docs/naming.md`, which now carries both words in the table with the rest of the window's vocabulary. Janela is a window, so the document saying where the project is going is the view through it, and the far half of that view is the horizon. The table is where a forker looks to see whether a name was reasoned about or reached for, which is the only reason a rename like this is worth writing down. The page also gains a drawing of what it describes: two receding bands under an empty sky, eight marks on the near one for the issues in 1.0 and three on the far one for the work past it, drawn in `currentColor` so it reads in a light or a dark theme without knowing which it is in (ADR 037).

## [0.8.0] - 2026-09-23

### Added

- `docs/theming.md`, "Theming Janela": the contract a theme may target. Every class the engine renders in your own pages, the three custom properties that carry `janela.css`, what a theme is expected to leave alone, and how to write one of your own. A theme is any stylesheet you name, `Janela.theme = "midnight"` resolving from your own asset paths, and vitral is one of them rather than the one. Ships in the gem; `test/dummy` has a live page at `/vitral` showing all of it against real panes (ADR 036).
- `janela-own-headings`, a class you put on any ancestor when your own markup already says what a pane is. A table pane's `<caption>` and a single value's label stop being drawn and stay in the accessibility tree. Hidden rather than removed on purpose: a caption is the table's accessible name, so `display: none` lands a screen reader on a grid of numbers with nothing to say what they measure, which is the easy wrong answer this saves you writing. A chart pane needs nothing, since its title was only ever an `aria-label` (ADR 036, #26).
- `docs/roadmap.md`, "Where Janela Is Going": what 1.0 means, which open issues are in it, and what is deliberately not coming. Three claims that can be checked rather than a feature count, since ADR 001 rules out a 1.0 measured against what a commercial BI tool ships: the public surface stops moving, a pane can be read, and the doctor can be trusted. It ships in the gem and renders on the demo at `/docs/roadmap`, because a reader who has to open an issue tracker to find out where a library is going has been told to do the maintainer's filing. It carries no dates on purpose, so that it can only ever be wrong about substance (ADR 037).

### Changed

- **Breaking.** `Janela.parent_controller=` raises when the assignment cannot take effect. The superclass of `Janela::ApplicationController` is resolved once, the first time the class loads, so naming a different controller after that did nothing at all: dashboards kept inheriting whatever was named first, and the host's authentication and `policy_scope` were not the ones it had written. Nothing said so. Set it in `config/initializers/janela.rb`, which runs before anything can load a Janela controller; `config.to_prepare` and `config.after_initialize` are both too late, and the README's own layout recipe is a `to_prepare` block that loads the controller. Naming the controller Janela already inherits is still allowed, since nothing is being asked for (ADR 035, #38).
- **The class names only Janela's own pages use are no longer public API.** ADR 016 said "the class names are public API", which read literally promised that `janela-card`, `janela-crumb`, `janela-flash`, `janela-button`, `janela-form` and the rest of the engine's own chrome would never be renamed without an upgrade note. That was a promise made to nobody about markup only the engine renders, and it made Janela's own pages harder to change than the library they serve. They are scoped under `janela-page`, which only the engine's layout sets, so they cannot reach your pages, and they may now change in any release. Everything a host's own markup contains, the grid scale and the pane primitives, is the contract and is unchanged: `docs/theming.md` lists it (ADR 036).

### Fixed

- Janela believes only the definitions Janela built. `Janela::Model` is extended onto every ActiveRecord model, so `janela` is a question any of them can answer, and an application whose own model defines a class method by that name wins the collision, as Ruby says it should. Janela treated anything truthy that came back as a definition: `rails janela:doctor` raised `NoMethodError: undefined method 'dimensions' for an instance of String`, a named subclass of that model was registered so `/dashboards/<its route key>/...` resolved, and `Janela.definitions` handed out a value that was not a definition to anything iterating it, such as a form offering a choice of model. Nothing about your own method changes; Janela ignores it now instead of choking on it. A *column* named `janela` was never affected either way, because an attribute is an instance method and this is a class method (#54, found while investigating #12).

- `rails janela:doctor`'s `through-dimensions-without-an-allowlist` reported once per dimension and once per class inheriting a declaration, where there is only ever one allowlist to write. Two dimensions reading through the same association produced two findings whose suggested lines contradicted each other, `%w[region]` and `%w[name]`, so pasting both kept the second and silently lost the first; an STI family produced a copy of each per subclass, since a subclass shares its parent's associations. It is now one finding per associated class, naming every column that class needs and every dimension that wants one, with a line that allows all of them. A subclass that reflects an association its parent does not still gets a finding of its own, because that is a different fix (#44).
- `rails janela:doctor` checked whether your controller *defines* `policy_scope` rather than whether calling it works, so a Pundit host with no policy for Janela's own models got a clean report and a `Pundit::NotDefinedError` on every dashboard request. Pundit defines `policy_scope` the moment it is included, whether or not the model has a policy, so for the commonest authorisation library those are different questions. `unscoped-reads` now makes the call Janela makes, against `Janela::Frame` and `Janela::Snapshot`, and reports a raise as an error quoting your own exception, which names the policy to write. ADR 032 called this check "exact: the method is defined or it is not"; ADR 035 supersedes that. Its other claim stands: Pundit raises rather than leaking, so nothing was ever exposed (ADR 035, #51).
- `frames-nobody-will-own` and `snapshots-nobody-will-see` never fired for any application whose `policy_scope` reaches for the signed in user, which is most of them. Both asked your policy on a controller with no request, where `session`, `params` and `current_user` are unreachable, and a blanket rescue read the resulting exception as "does not filter by owner". The checks now ask the way a request does, so those are empty rather than missing, which is an unauthenticated visitor and the right thing for a check to ask about. Expect findings that were always true and never printed (ADR 035).
- Every check about your controller read `Janela.parent_controller`, the setting, rather than `Janela::ApplicationController.superclass`, what Janela actually inherits. When a host named a parent controller too late the two differed, and the doctor reported on a class that was not in the chain, including the sentence "Janela's controllers inherit X" about a class it does not (ADR 035, #38).
- `hardcoded-disallowed-predicates` reported an error saying a file filters a model, having only found the dimension's name followed by a predicate somewhere under `app`, `config` or `lib`. An unrelated model's Ransack call, a comment warning against the predicate, and a key in a locale file all read the same to it, and a host was told an error about code that had nothing to do with Janela. It is now a warning, says the file *mentions* the key, and admits that it cannot tell which model a match belongs to. It also reports once per `janela` declaration rather than once per class inheriting it, so an STI family no longer multiplies the same finding (ADR 021, ADR 035, #51, part of #44).

## [0.7.0] - 2026-09-22

### Added

- `rails janela:doctor` reports snapshots stored with no owner when your policy filters snapshots by owner, as `snapshots-nobody-will-see`, a warning naming how many. Such a snapshot is stored and unreachable: the row is there, a link to it answers 404, and nothing says why. Usually they are snapshots taken before the owner column existed, which is what an upgrade produces. ADR 033 judged a check here a thinner case than the frame's, because a caller assigns a snapshot's owner in its own Ruby, and said it was worth revisiting if it bit: it bit four times in this repository's own tests and once on the live demo within an afternoon of the column landing (#49).
- A snapshot carries an owner, the same nullable polymorphic one a frame has, so a multi tenant application's policy has the same column to filter a snapshot on that it already has for a frame. `Janela::Snapshot.take(name:, owner:)` assigns it and `Janela::SnapshotJob` carries it across the queue through its GlobalID. Janela reads nothing from it, exactly as with a frame. It is an argument rather than a method on your controller because a snapshot is never taken in a request: there is no create route and no form, only `take` called from a job, a task or a console, where a hook reaching for the current tenant would work in a console and return nil in the job that is the point of the feature. Needs `rails janela:install:migrations` and a migrate; existing snapshots keep a nil owner and nothing breaks if you ignore it. The owner says who a snapshot belongs to and nothing about the numbers inside it, which is the separate question the `SnapshotJob` entry above answers (ADR 033, #32).

### Changed

- **Breaking.** `Janela::SnapshotJob` will not freeze a scope you have not named. It took every pane over the model's default scope, which ADR 009 chose deliberately because a relation cannot be serialised into a job. That is your tenant's rows if your tenancy is enforced on your models, and every row of every model if your scoping lives in your policies, and nothing reachable from a job can tell which application it is in: measured against a policy scoped host, the same application showed $150.00 on the live pane and published $375.00 from the snapshot beside it, under that tenant's own name, answered 200 with nothing in the log. A live unscoped read is wrong once, on a screen, to somebody already signed in; a snapshot freezes it into a row and serves it at an address to the external audience snapshots exist for. The job now asks one question, `scope_for(model)`, and refuses to answer it for you. A host whose tenancy is on its models, or who has one tenant, passes `scope: :model_default` and carries on. A host whose scoping is in its policies answers in Ruby, where a relation is still a relation, by subclassing the job and overriding `scope_for`, with `name`, `owner` and `filters` readable beside it so nothing has to override `perform`; that replaces the old advice to write a job around `Snapshot.take` from scratch. Neither answer raises `Janela::Unscoped`, the same refusal a request gets. `Snapshot.take` and `take.pane`'s `on:` are unchanged, because those are calls you write in your own Ruby. Note before deploying: a job already on the queue was serialised without `scope:` and will raise when it performs, which no diff will show you (ADR 034, #47).

- **Breaking.** Janela refuses to read a model it has not been told how to scope. `janela_scope` asked the host's controller for `policy_scope` and fell back to `model.all` when there was none, so an application using a different authorisation library, or none at all, got every row of every model on a dashboard with nothing said: a request that should have been a refusal answered 200 carrying numbers its reader may have had no right to, and no line mentioning scope reached the log. It now raises `Janela::Unscoped`, naming the method to define and the class to define it on. An application with nothing to hide answers once, `private def policy_scope(model) = model.all`, which is a sentence worth writing rather than inheriting by omission: "one tenant" and "everyone may read every row" are not the same claim. A host using Pundit is unaffected, including one missing a policy, because Pundit already raises on that. `rails janela:doctor` reports the absence as `unscoped-reads` at error severity, and unlike `unauthenticated-endpoints` it does not have to hedge, since the method is either defined or it is not (ADR 032, #7).

### Fixed

- A frame rendered in a host's own page read every row when `policy_scope` was a private controller method, which is the shape `docs/multi-tenancy.md` teaches and the shape Pundit's own has. Janela asked the view whether the host had defined a scope, where its own controllers ask the controller, and a view cannot see a private controller method: the same application was scoped on Janela's pages and silently unscoped on its own, with no error and nothing in the log. A host using Pundit was unaffected, because `Pundit::Helper` separately defines a view side copy. If you embed `janela_frame` or `janela_pane` in your own views and your scope narrows what a pane counts, those numbers were too high and are now correct (#46).

## [0.6.0] - 2026-09-20

### Added

- `janela_pane` takes an optional `id:`, naming the pane's frame instead of fingerprinting it from the query. A host that reconfigures a pane in place, a renderer toggle, a granularity switcher, a "show top 20" link, keeps one stable frame for Turbo to reconcile into rather than a different id every time the query changes. Without `id:`, nothing changes.
- A `janela--frame:repoint` event, dispatched on a pane or anything inside one with `detail: { url }`, sends that pane to a different query. `janela_frame` listens for it, so nothing has to be wired up and nothing has to reach for the controller. This is how a host changes what a pane shows: a pane's `src` belongs to Turbo, which writes it back whenever a response lands, so Janela keeps its own record of what was asked for and cancels anything else, a host's `src` write included. The event says the query and nothing about filters, because the frame reapplies whatever it is currently filtered to. `data-janela-asked` and `data-janela-src` are how the frame remembers, not an interface, and a host reading or writing them is relying on something that may change (ADR 030, #43).
- A subclass inherits the dashboard its parent declared and is addressable on its own route key, with nothing to declare: `class WholesaleOrder < Order; end` answers at `/dashboards/wholesale_orders/revenue` and totals its own rows, because the query runs on the subclass and ActiveRecord adds the type condition itself. This is a change of posture, since only a model that declared a `janela` block was addressable before, and it is one of URL surface rather than data surface: an STI subclass is a subset of rows its parent already totals, read through the same scope as everything else. A subclass that wants a different dashboard declares its own block, which replaces its parent's. The cost is noise: a family of a dozen STI types is a dozen entries in `Janela.definitions` and in the form that offers a choice of model, where a host expected one (ADR 031, #11).

### Fixed

- A subclass came out half declared: it inherited the Ransack allowlist, because Janela defined that as singleton methods on the parent and singleton methods inherit, while `.janela` returned nil and nothing was registered. A host calling `WholesaleOrder.ransack(...)` in its own code was filtering on dimensions no definition behind that class declared. The allowlist Janela generates is now the allowlist of the definition a class reports, whichever class declared it, and a subclass declaring its own block no longer replaces an allowlist the host wrote on a parent (ADR 031, #11).
- Pointing a pane's turbo frame at a URL differing only in `limit`, `granularity` or `as` left the frame stale with no error. The response was fingerprinted from the query, so it wore an id the frame never had and Turbo had nothing to reconcile it against. A pane rendered into a turbo frame request now answers to the frame that asked, using the id Turbo already sends in its `Turbo-Frame` header, rather than deriving one again from the query. A pane rendered any other way keeps deriving its own id as before. The demo's gallery config controller no longer fetches and swaps a pane's frame by hand: it names each configurable pane and asks the frame to repoint it, which is 22 lines shorter than where it started (ADR 029, #42).
- Reconfiguring a pane while the frame was filtered refetched that pane unfiltered, so it showed numbers for a filter state nobody was in while every pane beside it stayed filtered, and nothing on the page said so. Reapplying the frame's current filters is part of repointing now rather than something a caller has to remember, which is what the demo's gallery control got wrong: change a pane's granularity there with a value selected and it went back to showing the year (ADR 003, ADR 030, #43).

## [0.5.0] - 2026-09-18

### Added

- `Janela.renderers`, `Janela.granularities` and `Janela.offered_limits`, alongside the existing `Janela.definitions`, so a gallery of what Janela can draw asks the gem rather than reading `Janela::Query::RENDERERS`, `Janela::Dimension::GRANULARITIES` or `Janela::Pane::OFFERED_LIMITS` directly. `test/dummy`'s `/gallery` is the reference page ADR 027 describes, built from exactly that surface plus `janela_pane`: a live pane per renderer per model, with the declaration that produced it beside it. A renderer a model cannot demonstrate, for want of a suitable dimension, is shown as unavailable rather than hidden, and a host with no `janela` models yet gets an explanation rather than a blank page (ADR 026, ADR 027, #39).

### Changed

- **Breaking.** A filter is bound to what kind of dimension it names rather than to every predicate Ransack knows. Every one of Ransack's 62 predicates worked on any allowed attribute, `_matches` sharpest among them: an arbitrary `LIKE` pattern, a leading wildcard scan away, on a page a host had already authorised someone to read. A categorical dimension now takes `eq`, `in`, `null` and `not_null`; a time dimension additionally takes `gteq`, `gt`, `lteq` and `lt`, which is exactly what a click produces (ADR 024) plus the range narrowing ADR 006 already documented. Anything else raises `Janela::BadRequest` naming the filter and what the dimension allows, rather than Ransack silently dropping it and a pane showing a number nobody asked for. A grouped query with no `limit` now gets one anyway, at the existing ceiling of 1000 (ADR 007); a single filter may carry at most 1000 values. `rails janela:doctor` finds a hardcoded filter that used a predicate no longer allowed, when it is written in the host's own source rather than read from a URL (ADR 025, #8).

## [0.4.1] - 2026-09-17

### Fixed

- `Janela::HostRoutes.forwarded` could return an empty set. Route loading is lazy, so calling it before anything had drawn the host's routes, such as from a host's own initializer, silently forwarded nothing rather than raising. It now draws the routes first if they are not already loaded (#37).

## [0.4.0] - 2026-09-17

### Added

- `docs/naming.md`, "Naming Things Is Hard": why Janela's words are uncommon but conceivable, the anatomy of the window, which words stay ordinary and why, how a host puts its own words in front of its users, and a checklist for naming anything new. Ships in the gem.
- The vitral lattice leans toward the pointer with its outer edge pinned, drifts at two depths as the page scrolls, and reads its lead colour from `--vitral-lattice-ink`, so the live and static lattices cannot disagree.
- More than one value can be selected in a dimension. Ctrl or Cmd click adds a value and takes it out again while the rest stay; a plain click still selects one and clears the dimension when it was the only one. A chart highlights every selected bar and answers the same modifier. Escape clears the frame's filters. All of it works from the keyboard, because a value is already a real button and a browser puts the same modifier on the click it makes from Enter (ADR 024, #35, #36).
- `vitral.css`, an optional theme that makes a dashboard a stained glass window: each pane holds one of five colours, dark leading runs between them and the light comes from behind. Separate from `janela.css` on purpose, which stays structure while this is taste (ADR 023). Link it, put `class="vitral"` on the element that carries the light, and use `vitral-pane`, `vitral-panes` and `vitral-button` on your own markup to match. Retheme it from the `--vitral-*` custom properties rather than by forking it.
- `Janela.theme`, naming the stylesheet Janela's own pages load on top of `janela.css`. Unset by default, so nothing changes for a host that has its own look.
- `janela/vitral_controller`, optional and separate again: it draws the leadlight live and every node leans toward the pointer. Reduced motion, reduced transparency and increased contrast each get a still, solid window instead.

### Changed

- The copyright holder is Retail Tasker. The licence is still MIT, and earlier releases keep the notice they shipped with.
- A click writes Ransack's `_in` rather than `_eq`, one value or five, so there is one shape in the controller, the view and a stored snapshot. A link already shared with `_eq` keeps working and still reads as selected. `Query#selected_value` is now `selected_values` and returns an array, which matters only to a host that overrode a pane view (ADR 024).
- The null group is exclusive within its dimension. Ransack ands its conditions, so `(none)` together with a value asks for rows that are both null and not, and returns nothing at all. Selecting either now clears the other rather than rendering an empty dashboard that looks like a bug.

### Fixed

- A pane could show numbers for filters nobody had asked for. A pane's first load is lazy, so a request that began before a click could land after it, and Turbo renders whatever arrives and leaves the URL it fetched on the frame. Janela now keeps its own record of what it asked each pane for, and cancels any request for anything else before it can land, rather than trying to correct a wrong render afterwards. A page opened from a filtered link also no longer reloads every pane the moment it connects, which was both wasted work and the most common source of the stale request (#33).
- Janela's own pages were a dead end: nothing on them linked back to the application they belong to. They now carry one link to the host's root, when the host has one, labelled from i18n like every other word the engine renders. This was not possible before host route helpers resolved inside the engine (ADR 011, ADR 022).
- A host's own route helpers work inside Janela's controllers and views. `isolate_namespace` pointed every helper at the engine's routes, so host code that runs there and generates a URL raised: an authentication concern redirecting to `new_session_path`, a `rescue_from`, an `after_action`. An unauthenticated visitor got a 500 instead of a sign-in page. Janela now forwards exactly the helpers the engine does not define itself, so nothing of Janela's can be shadowed by a host route of the same name, and `main_app.` still says either unambiguously. Polymorphic `url_for(@record)` has no name to forward and still needs the prefix (ADR 022, #23).
- The README explained this as something to do "if your app authenticates per controller", which was wrong about the cause. The trigger is generating a URL inside the engine, whenever authentication runs.

## [0.3.0] - 2026-09-16

### Added

- `docs/multi-tenancy.md`, shipped in the gem: what goes through the host's scope and what does not, worked wiring for Pundit, acts_as_tenant and CanCanCan, what owns a frame an analyst creates, how to prove it with a test, and the honest note that a snapshot has no owner column yet (#32).
- A measure declares how its number reads: `precision:`, `prefix:` and `suffix:`, applied the same way to a table cell, a single value and a chart tooltip. Precision defaults to what the schema already says, so counting rows is whole, a `decimal(10, 2)` column reads to the cent and only an average of an integer falls back to two places. Formatting is rendering, never rounding: a snapshot stores the number and reads back under whatever format is declared later (ADR 020, #25).
- A pane whose row asks for a chart renders as its table where no chart runtime exists, which is the engine's own pages; a host's page still draws the chart. `janela_frame(@frame, charts: false)` asks for it explicitly (ADR 018).
- The engine's layout loads Janela's own stylesheet, so its pages are styled on install. It still loads none of the host's assets.
- The analyst's editing surface: conventional Rails CRUD on frames and on panes nested under a frame, on Janela's own pages, working with nothing but HTML. Adding a pane is two steps, the first picking a model and the second offering only the measures and dimensions that model declares, because those pages run no JavaScript to refill one select from another. A pane moves with Up and Down buttons rather than a position field, and positions stay contiguous. Every action reads through the host's scope, so another tenant's frame is a 404 to change as well as to read (ADR 012, ADR 014).
- `janela_frame_owner`, a hook a host defines on its own `ApplicationController`. Janela assigns its return value as the owner of a frame it creates, so a host whose `policy_scope` filters frames by owner does not have the analyst's new dashboard hidden the instant it is saved. A host with no tenancy defines nothing and gets a nil owner. Duck typed, like `policy_scope` itself.
- Janela serves its own pages: an index of frames and a page per frame, at the mount root (`/dashboards`, `/dashboards/3`). Both read through the host's `policy_scope`, the noun in every heading comes from `Janela::Frame.model_name.human` so a host renames it in its own locale file, and the gem ships `config/locales/en.yml` with the English defaults. A host that wants a different index writes its own page over `Janela::Frame` and never routes to ours (ADR 013).
- A dashboard can be data. `Janela::Frame` holds a name and a grid (`columns` 1 to 12, `gap` 0 to 8), `Janela::Pane` holds one visual (`position`, `span` 1 to 12, model, measure, dimension, renderer, granularity, limit and an optional title of its own), and `janela_frame @frame` renders one. The block form is unchanged, so nothing already built has to move (ADR 012, ADR 014). Run `bin/rails janela:install:migrations && bin/rails db:migrate` for the two new tables.
- A pane row is rendered by its own nested route, `<mount>/:frame_id/panes/:id`, and identified in the DOM as `janela_pane_<id>`, so two rows showing the same measure by the same dimension do not share a turbo frame. The ad hoc pane grammar from ADR 005 is unchanged.
- A frame renders every pane inline on the first response, so a shared link is a correct dashboard before any JavaScript runs and a page load makes no request per pane. Filters in the page URL apply to every pane either way.
- A pane row is validated against the registry on save: the model must have a `janela` block, the measure, dimension, renderer and granularity must be declared or supported, a granularity only applies to a time dimension, and a limit is 1 to 1000. A bad row is rejected with a readable message rather than rendering as a missing pane later.
- `Janela::Frame belongs_to :owner, polymorphic: true, optional: true`. Janela sets nothing there and reads nothing from it; it exists so a multi tenant host's Pundit `Scope` has a column to filter on. Every lookup of a frame or a pane row goes through that scope, so another tenant's frame is a 404 (ADR 014).
- A stylesheet, `app/assets/stylesheets/janela.css`, which a host includes with `stylesheet_link_tag "janela"`. It defines the grid classes for every value the records allow, styles the existing `janela-pane`, `janela-chart`, `janela-value` and `janela-empty` hooks so a pane is legible on install (#15), and collapses to one column on a narrow screen. Set `--janela-space` to move the whole spacing scale. The engine never injects it into a layout it does not own (ADR 016).
- `bin/rails janela:doctor` reads a host application and lists what it still needs to do: identifiers from an earlier version, unregistered Stimulus controllers, a `through:` dimension whose associated model has no allowlist, an unmounted engine, a mounted engine whose tables were never migrated, a `policy_scope` that filters frames by owner where the host defines no `janela_frame_owner`, and whether anything authenticates the endpoints. Exits non-zero on an error so it can run in CI (ADR 015). Every finding names the check that produced it, such as `unauthenticated-endpoints`, and a host silences one it has judged a false alarm with `Janela.silenced_checks`. A silenced check is still named in the output every run (ADR 021).
- `UPGRADING.md`, shipped inside the gem, with the steps for each release that needs a host to act. The changelog says what changed; the upgrade guide says what to do.

### Changed

- Numbers render to the precision the measure means rather than to whatever the database returned. A sum of a `decimal(10, 2)` column that read as `375.0` now reads as `375.00`, and an average that read as `928.8767833333333` now reads as `928.88`. Nothing is rounded before it is stored or compared (ADR 020).
- Janela's own minimal layout now links the gem's own stylesheet, refining ADR 011. It still loads nothing of the host's, and still no JavaScript, because Turbo and Stimulus come from the host's bundler: Janela's own pages are therefore correct, styled, static dashboards. Panes render inline and filters in the URL apply; nothing cross-filters, and a chart pane draws nothing there. The engine also declares `janela.css` for precompilation, so a host on Sprockets serves it in production.
- A snapshot is read through the host's scope rather than `Snapshot.find`, so a stored pane a host's policy hides is a 404 rather than a result anyone who guesses an id can read (ADR 014).
- The frame controller no longer rewrites pane `src` attributes when it connects, only when the filters actually change. A pane rendered inline would otherwise be fetched again immediately and its first render thrown away.
- A frame or a pane a host's scope cannot see now answers with Janela's own sentence inside the requesting turbo frame, rather than the host's error page. Still a 404.
- Breaking rename, no behaviour change (ADR 014). A host must act on all of these:
  - The Stimulus controller `janela--dashboard` is now `janela--frame`, and its file is `frame_controller.js`. Change `application.register("janela--dashboard", ...)` to `application.register("janela--frame", ...)`, and the import path from `@retail-tasker/janela/dashboard_controller` to `@retail-tasker/janela/frame_controller` on npm, or `janela/dashboard_controller` to `janela/frame_controller` on importmap.
  - Any `data-action="janela--dashboard#clear"` (or `#toggle`), `data-janela--dashboard-*-param` and `data-janela--dashboard-target` in the host's own markup becomes `janela--frame`.
  - The helper `janela_dashboard do ... end` is now `janela_frame do ... end`. `janela_pane` and `janela_snapshot_pane` are unchanged.
  - The helper module `Janela::DashboardHelper` is now `Janela::FramesHelper`, which only matters to a host that includes or overrides it.
  - `Janela::Pane` is now `Janela::Query`, and its `frame_id` is `turbo_frame_id`. `Pane` is reserved for a future record. Frame unqualified now means the dashboard; the DOM element is always spelled turbo frame.
  - `Janela::PanesController` is now `Janela::QueriesController` and `Janela::SnapshotPanesController` is now `Janela::SnapshotQueriesController`, with their views at `app/views/janela/queries/`. A host that overrides the view moves its copy.
  - `test/query_test.rb` is now `definition_query_test.rb`, since `query_test` read as a test of `Janela::Query` rather than of `Definition#query`.
  - Unchanged on purpose: the pane URLs, the route helpers `pane_path` and `snapshot_pane_path`, the turbo frame ids, and the CSS hooks `janela-pane`, `janela-chart`, `janela-value` and `janela-empty`.
- The README's advice on styling a directly opened pane was wrong: it suggested pointing Janela at the host's application layout, which is the thing that raises `NameError` inside an isolated engine. It now shows a small asset-only layout instead, the pattern a real host arrived at.

## [0.2.1] - 2026-09-15

Fixes found by dogfooding 0.2.0 in a second application. 0.2.0 is unusable in any host whose layout contains a route helper, which is most of them.

### Fixed

- Panes rendered in the host's application layout, so any route helper in it raised `NameError` inside the isolated engine and every pane 500'd. A pane in a Turbo Frame now carries no layout; opened directly it uses Janela's own minimal layout (ADR 011, #19).
- `average:` or `sum:` over a boolean column returned `true` instead of a ratio, because ActiveRecord casts an aggregate back through the column's type. Declaring one now raises and points at `dimension` instead (#20).
- A group whose dimension is null rendered as a blank label and filtered on an empty string. It is now labelled `(none)` and toggles Ransack's null predicate (#21).
- The README claimed time buckets follow `Time.zone`; on SQLite they are UTC, which silently shifts daily buckets by the host's offset (#22).

### Changed

- A request for a model, measure, dimension or stored pane that does not exist is a 404; a renderer, granularity, limit or filter the request may not use is a 400. The response is a plain sentence, inside the requesting Turbo Frame when there is one, and the detail goes to the log instead of the client. `Janela::NotFound` and `Janela::BadRequest` subclass `Janela::Error`.

## [0.2.0] - 2026-09-15

Breaking. Renames and a new URL scheme while the only installation is the author's own (ADR 005).

### Changed

- `janela_visual` is now `janela_pane`; `Janela::Visual` is `Janela::Pane`; CSS hooks are `janela-pane`, `janela-chart`, `janela-value`, `janela-empty`.
- A pane's URL is `/<mount>/<model route key>/<measure>[/<dimension>]?as=bar&q[...]` instead of `/<mount>/visual?model=...`. Frame ids follow the same shape.
- The gem no longer ships its Rakefile, which referenced the unshipped dummy application.
- The helper finds the engine's mount in the host's routes, so `mount Janela::Engine => "/reports", as: :reports` works. Documentation and the dummy application mount at `/dashboards`.

### Added

- A pane with no dimension renders the measure's single total.
- Time dimensions: `dimension :placed_on, granularity: :month` buckets with Groupdate (`hour` to `year`), gap-filled, labelled in Ruby. Override per pane with `?granularity=week` or `janela_pane ..., granularity: :week`. Time panes re-scope with the dashboard but are not yet click sources (ADR 006).
- `as: :line` renderer for time series.
- Groupdate is a runtime dependency.
- Published to rubygems.org through trusted publishing; a public demo of `test/dummy` deploys from `main`.
- Snapshots: `Janela::Snapshot.take` freezes several panes' results at one instant under one set of filters; `janela_snapshot_pane` renders a stored pane, static by nature, at `/snapshots/:id/<model>/<measure>[/<dimension>]`. `Janela::SnapshotJob` for scheduling. First migration: `rails janela:install:migrations` (ADR 009).
- Dashboard filters live in the page URL as `q[...]`; a reload keeps them and a filtered dashboard is shareable. The server renders the initial state from `params[:q]` (ADR 008).
- Category panes are ordered by their measure, largest first, in SQL. `?limit=N` / `janela_pane ..., limit: N` keeps the top N (ADR 007).
- `dimension :customer, through: :customer, column: :name` names a dimension for its meaning while reading another column.


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

[0.8.0]: https://github.com/retail-tasker/janela/releases/tag/v0.8.0
[0.7.0]: https://github.com/retail-tasker/janela/releases/tag/v0.7.0
[0.6.0]: https://github.com/retail-tasker/janela/releases/tag/v0.6.0
[0.5.0]: https://github.com/retail-tasker/janela/releases/tag/v0.5.0
[0.4.1]: https://github.com/retail-tasker/janela/releases/tag/v0.4.1
[0.4.0]: https://github.com/retail-tasker/janela/releases/tag/v0.4.0
[0.3.0]: https://github.com/retail-tasker/janela/releases/tag/v0.3.0
[0.2.1]: https://github.com/retail-tasker/janela/releases/tag/v0.2.1
[0.2.0]: https://github.com/retail-tasker/janela/releases/tag/v0.2.0
[0.1.0]: https://github.com/retail-tasker/janela/releases/tag/v0.1.0
