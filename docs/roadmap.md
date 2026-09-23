---
Topics: roadmap, releases, scope, planning
---

# Vista

*Janela* is Portuguese for window. This is the view through it: what is
close enough to make out, what is still on the horizon, and what is not
in the picture at all.

<svg viewBox="0 0 760 336" width="100%" height="auto" role="img" aria-labelledby="vista-title vista-desc" style="max-width: 760px; display: block; margin: 2rem auto;">
  <title id="vista-title">The view from Janela</title>
  <desc id="vista-desc">A landscape seen through a window. The near band carries eight marks, the eight issues in 1.0. The band behind it, fainter, carries three: the work on the horizon, wanted but not blocking. Above the horizon line the sky is empty, because what is not coming is not in view.</desc>

  <defs>
    <clipPath id="vista-pane"><rect x="11" y="11" width="738" height="298"/></clipPath>
  </defs>

  <g clip-path="url(#vista-pane)">
    <path d="M11 92 H749" fill="none" stroke="currentColor" stroke-width="1.5" opacity="0.26"/>

    <path d="M11 126 L150 114 L300 124 L450 110 L600 118 L749 108 L749 309 L11 309 Z"
          fill="currentColor" opacity="0.05"/>
    <g fill="none" stroke="currentColor" stroke-linecap="round">
      <path d="M11 126 L150 114 L300 124 L450 110 L600 118 L749 108" stroke-width="1.5" opacity="0.3"/>
      <path d="M330 121 V110" stroke-width="2" opacity="0.42"/>
      <path d="M460 111 V100" stroke-width="2" opacity="0.42"/>
      <path d="M590 118 V107" stroke-width="2" opacity="0.42"/>
    </g>

    <path d="M11 238 L120 224 L240 236 L360 222 L480 232 L600 218 L749 230 L749 309 L11 309 Z"
          fill="currentColor" opacity="0.11"/>
    <g fill="none" stroke="currentColor" stroke-linecap="round">
      <path d="M11 238 L120 224 L240 236 L360 222 L480 232 L600 218 L749 230" stroke-width="1.5" opacity="0.45"/>
      <path d="M90 228 V206" stroke-width="2.5" opacity="0.8"/>
      <path d="M175 230 V208" stroke-width="2.5" opacity="0.8"/>
      <path d="M260 234 V212" stroke-width="2.5" opacity="0.8"/>
      <path d="M345 224 V202" stroke-width="2.5" opacity="0.8"/>
      <path d="M430 228 V206" stroke-width="2.5" opacity="0.8"/>
      <path d="M515 228 V206" stroke-width="2.5" opacity="0.8"/>
      <path d="M600 218 V196" stroke-width="2.5" opacity="0.8"/>
      <path d="M680 224 V202" stroke-width="2.5" opacity="0.8"/>
    </g>
  </g>

  <g fill="none" stroke="currentColor">
    <rect x="19" y="19" width="722" height="282" stroke-width="1" opacity="0.18"/>
    <rect x="11" y="11" width="738" height="298" stroke-width="2.5" opacity="0.4"/>
    <path d="M0 316 H760" stroke-width="4" opacity="0.45"/>
    <path d="M6 324 H754" stroke-width="1" opacity="0.2"/>
  </g>

  <g fill="currentColor" font-size="11" letter-spacing="0.1em" text-anchor="middle">
    <text x="380" y="176" opacity="0.4">HORIZONTE</text>
    <text x="380" y="278" opacity="0.5">IN 1.0</text>
  </g>
</svg>

Janela is alpha. It works, it is tested against a real Rails application
in a real browser, and its public surface has changed in three of the
last four releases. This page says what has to be true before that stops,
what is in the next release, and what is deliberately not coming. The
reasoning behind it is ADR 037.

## What 1.0 means

Not that Janela is finished. ADR 001 commits the project to the
load-bearing 5% of a BI tool and to staying small enough to fork, so a
1.0 measured against what a commercial tool ships would never arrive.

1.0 is three claims you can check.

**The public surface stops moving.** Everything listed as the contract in
[Theming Janela](theming), the measures and dimensions DSL, `janela_pane`
and `janela_frame`, the pane URL shape and the dashboard filter
parameters change only on a major version after 1.0. Until then they can
change in any release, and every change of that kind carries an entry in
`UPGRADING.md`.

**A pane can be read.** Janela draws tables, bars and lines. A
part-to-whole split currently has to be drawn as bars, a table row cannot
carry context beside its label, and a chart takes Chart.js's default
proportions whether or not they suit the page. Those are not extra
features. They are the 5% not finished, and most of them were found by
people installing the gem rather than reading it.

**The doctor can be trusted.** `rails janela:doctor` checks an
installation for the mistakes that produce a dashboard showing numbers
nobody should see. Two of its checks have no test that makes them fire.
A check nobody can prove is working is a check nobody should rely on.

## In 1.0

The eight marks on the near band.

| Issue | What |
| --- | --- |
| [#24](https://github.com/retail-tasker/janela/issues/24) | A chart's height and aspect ratio are the host's to set |
| [#27](https://github.com/retail-tasker/janela/issues/27) | A ratio measure, so refusing `average:` over a boolean offers somewhere to go |
| [#30](https://github.com/retail-tasker/janela/issues/30) | Doughnut and pie, and a categorical palette that makes them readable |
| [#31](https://github.com/retail-tasker/janela/issues/31) | A pane says how prominent it is |
| [#34](https://github.com/retail-tasker/janela/issues/34) | A table pane carries an attribute column beside its label |
| [#53](https://github.com/retail-tasker/janela/issues/53) | The last two doctor checks get tests |
| [#14](https://github.com/retail-tasker/janela/issues/14) | A Sprockets host serves the engine's JavaScript, or is told it cannot |
| [#6](https://github.com/retail-tasker/janela/issues/6) | How contributions are accepted, who cuts a release, where to report a vulnerability |

Progress is tracked on the
[1.0 milestone](https://github.com/retail-tasker/janela/milestone/2).

## Horizonte

The band behind it, still in sight. Wanted, not blocking a stable
release, and being on this list is not a refusal.

- **Drill-down on time panes** ([#18](https://github.com/retail-tasker/janela/issues/18)).
  Clicking a month could filter every other pane to it, or narrow that
  pane to weeks within it. Both are reasonable, they need different
  things from the URL, and ADR 006 left the question open on purpose. It
  needs a decision record before any code.
- **A command palette for the demo** ([#41](https://github.com/retail-tasker/janela/issues/41)).
  The demo site, not the gem.
- **A scroll drift on the gallery page** ([#45](https://github.com/retail-tasker/janela/issues/45)).
  Cosmetic, demo only, and possibly not worth fixing.

## Not coming

The sky above the horizon is empty, and that is the honest part of the
picture. Janela is meant to be small enough that forking it and adding
your own piece is a normal way to use it. These are the things you would
be adding yourself, and each is left out because something you already
run does it better.

Natural-language query. A separate data warehouse. A row-level-security
subsystem, because your application already has Pundit or CanCanCan and
Janela reads through it. A refresh-scheduling interface, because you
already have a scheduler and snapshots are an ActiveJob. An embedding
SDK. A mobile application. Print and paginated reports. A drag-and-drop
visual dashboard designer, though frames and panes are database records,
so an application can build its own editor on top of them.

Whether Janela should help arrange panes on a page is genuinely open
([#29](https://github.com/retail-tasker/janela/issues/29)). The default
answer is that layout belongs to your application, and changing it would
need a decision record first.

## How this page stays honest

It is updated when a release lands, not on a schedule, and it carries no
dates. A roadmap with dates on a project this size would be wrong within
a fortnight and would train you to ignore it. If something here has been
true for a long time and nothing has moved, that is worth reading as the
signal it is.
