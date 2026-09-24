---
Topics: roadmap, releases, scope, planning
---

# Vista

<p style="text-align: center;">Vista shows where Janela is heading.</p>

<svg viewBox="0 0 680 360" width="100%" role="img" aria-labelledby="vista-title vista-desc" class="vista-art" style="display: block; margin: 1.75rem 0; border-radius: 10px;">
  <title id="vista-title">Vista</title>
  <desc id="vista-desc">Sea and sky with a horizon across them. Eight lights burn on the near water, one for each issue in 1.0, and three sit far off at the horizon for the work still in sight past it. A low sun rises and sets on the horizon as the pointer moves up and down, and never climbs higher: the sky above is empty, because what is not coming is not in view.</desc>

  <style>
    .vista-art .v-far { transform: translate3d(calc(var(--vitral-shift-x, 0) * 13px), calc(var(--vitral-shift-y, 0) * 7px), 0); transition: transform .45s cubic-bezier(.2,.7,.3,1); }
    .vista-art .v-mid { transform: translate3d(calc(var(--vitral-shift-x, 0) * 6px), calc(var(--vitral-shift-y, 0) * 3px), 0); transition: transform .45s cubic-bezier(.2,.7,.3,1); }
    .vista-art .v-near { transform: translate3d(calc(var(--vitral-shift-x, 0) * -8px), calc(var(--vitral-shift-y, 0) * -4px), 0); transition: transform .45s cubic-bezier(.2,.7,.3,1); }
    .vista-art .v-glow-a { opacity: calc(.6 - var(--vitral-shift-x, 0) * 1.2); transform: translate3d(calc(var(--vitral-shift-x, 0) * -40px), calc(var(--vitral-shift-y, 0) * 16px), 0); transition: transform .9s cubic-bezier(.2,.7,.3,1), opacity .9s ease; }
    .vista-art .v-glow-b { opacity: calc(.6 + var(--vitral-shift-x, 0) * 1.2); transform: translate3d(calc(var(--vitral-shift-x, 0) * 44px), calc(var(--vitral-shift-y, 0) * -14px), 0); transition: transform .9s cubic-bezier(.2,.7,.3,1), opacity .9s ease; }
    .vista-art .v-sun { transform: translate3d(calc(var(--vitral-shift-x, 0) * 10px), calc(var(--vitral-shift-y, 0) * 84px), 0); transition: transform 1.1s cubic-bezier(.2,.7,.3,1); }
    .vista-art .v-glint { opacity: calc(.45 - var(--vitral-shift-y, 0) * .9); transform: translate3d(calc(var(--vitral-shift-x, 0) * 10px), 0, 0); transition: opacity 1.1s ease, transform 1.1s cubic-bezier(.2,.7,.3,1); }
    @media (prefers-reduced-motion: reduce) {
      .vista-art .v-sun, .vista-art .v-glint { transform: none; opacity: .45; }
      .vista-art .v-far, .vista-art .v-mid, .vista-art .v-near, .vista-art .v-glow-a, .vista-art .v-glow-b { transform: none; opacity: .6; }
    }
  </style>

  <defs>
    <clipPath id="vFrame"><rect x="0" y="0" width="680" height="360" rx="10"/></clipPath>
    <clipPath id="vAbove"><rect x="0" y="0" width="680" height="196"/></clipPath>
    <radialGradient id="vSun">
      <stop offset="0" stop-color="#FFF4D6" stop-opacity="0.95"/>
      <stop offset="0.7" stop-color="#FFD58A" stop-opacity="0.9"/>
      <stop offset="1" stop-color="#F7A96B" stop-opacity="0.75"/>
    </radialGradient>
    <radialGradient id="vSunHalo">
      <stop offset="0" stop-color="#FFD98F" stop-opacity="0.5"/>
      <stop offset="1" stop-color="#F7A96B" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="vSky" x1="0" y1="0" x2="0.22" y2="1">
      <stop offset="0" stop-color="#5B49C9" stop-opacity="0.54"/>
      <stop offset="0.38" stop-color="#8A6EE4" stop-opacity="0.34"/>
      <stop offset="0.7" stop-color="#E06082" stop-opacity="0.29"/>
      <stop offset="1" stop-color="#F0B046" stop-opacity="0.46"/>
    </linearGradient>
    <linearGradient id="vSea" x1="0" y1="0" x2="0.08" y2="1">
      <stop offset="0" stop-color="#F0B046" stop-opacity="0.34"/>
      <stop offset="0.22" stop-color="#1CA89E" stop-opacity="0.38"/>
      <stop offset="1" stop-color="#132F5C" stop-opacity="0.78"/>
    </linearGradient>
    <radialGradient id="vLamp">
      <stop offset="0" stop-color="#FFE9B8" stop-opacity="0.78"/>
      <stop offset="1" stop-color="#FFD98F" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="vP1"><stop offset="0" stop-color="#367AEB" stop-opacity="0.6"/><stop offset="1" stop-color="#367AEB" stop-opacity="0"/></radialGradient>
    <radialGradient id="vP2"><stop offset="0" stop-color="#1CA89E" stop-opacity="0.30"/><stop offset="1" stop-color="#1CA89E" stop-opacity="0"/></radialGradient>
    <radialGradient id="vP3"><stop offset="0" stop-color="#E06082" stop-opacity="0.5"/><stop offset="1" stop-color="#E06082" stop-opacity="0"/></radialGradient>
  </defs>

  <g clip-path="url(#vFrame)">
    <g class="v-far">
      <rect x="-30" y="-30" width="740" height="256" fill="url(#vSky)"/>
      <ellipse class="v-glow-a" cx="150" cy="104" rx="230" ry="132" fill="url(#vP1)"/>
      <ellipse class="v-glow-b" cx="520" cy="140" rx="250" ry="100" fill="url(#vP3)"/>
    </g>

    <g clip-path="url(#vAbove)">
      <g class="v-sun">
        <circle cx="432" cy="192" r="96" fill="url(#vSunHalo)"/>
        <circle cx="432" cy="192" r="24" fill="url(#vSun)"/>
      </g>
    </g>
    <g class="v-mid">
      <rect x="-30" y="196" width="740" height="204" fill="url(#vSea)"/>
      <ellipse cx="580" cy="288" rx="220" ry="124" fill="url(#vP2)"/>
      <path d="M6 200.0 h18 M46 200.0 h18 M80 200.0 h11 M145 200.0 h9 M173 200.0 h8 M204 200.0 h22 M235 200.0 h7 M266 200.0 h18 M305 200.0 h19 M339 200.0 h23 M372 200.0 h30 M424 200.0 h24 M490 200.0 h16 M519 200.0 h30 M555 200.0 h12 M581 200.0 h30 M618 200.0 h22 M650 200.0 h9" stroke="#FFF3DA" stroke-opacity="0.28" stroke-width="1" stroke-linecap="round"/>
      <path d="M74 204.2 h12 M100 204.2 h12 M195 204.2 h28 M245 204.2 h13 M384 204.2 h10 M404 204.2 h23 M441 204.2 h31 M527 204.2 h30 M568 204.2 h12 M604 204.2 h12 M639 204.2 h23 M669 204.2 h8" stroke="#FFF3DA" stroke-opacity="0.28" stroke-width="1" stroke-linecap="round"/>
      <path d="M127 209.4 h23 M169 209.4 h16 M278 209.4 h32 M329 209.4 h27 M398 209.4 h27 M431 209.4 h25 M477 209.4 h17 M501 209.4 h23 M548 209.4 h28 M598 209.4 h33 M650 209.4 h32" stroke="#FFF3DA" stroke-opacity="0.27" stroke-width="1" stroke-linecap="round"/>
      <path d="M6 215.8 h32 M56 215.8 h27 M148 215.8 h38 M208 215.8 h20 M247 215.8 h22 M370 215.8 h23 M487 215.8 h35 M538 215.8 h35 M593 215.8 h15 M631 215.8 h36" stroke="#FFF3DA" stroke-opacity="0.26" stroke-width="1" stroke-linecap="round"/>
      <path d="M6 223.7 h28 M44 223.7 h26 M96 223.7 h32 M141 223.7 h15 M169 223.7 h17 M207 223.7 h26 M258 223.7 h41 M308 223.7 h11 M326 223.7 h32 M492 223.7 h30 M543 223.7 h31" stroke="#FFF3DA" stroke-opacity="0.25" stroke-width="1" stroke-linecap="round"/>
      <path d="M56 233.5 h23 M99 233.5 h33 M149 233.5 h39 M197 233.5 h44 M252 233.5 h27 M308 233.5 h24 M361 233.5 h39 M477 233.5 h40 M542 233.5 h18 M591 233.5 h46 M664 233.5 h22" stroke="#FFF3DA" stroke-opacity="0.24" stroke-width="1" stroke-linecap="round"/>
      <path d="M52 245.5 h34 M107 245.5 h13 M246 245.5 h33 M309 245.5 h40 M494 245.5 h38 M562 245.5 h35 M615 245.5 h46" stroke="#FFF3DA" stroke-opacity="0.22" stroke-width="1" stroke-linecap="round"/>
      <path d="M6 260.4 h52 M147 260.4 h37 M193 260.4 h58 M271 260.4 h50 M414 260.4 h33 M482 260.4 h26 M521 260.4 h33 M589 260.4 h35 M639 260.4 h42" stroke="#FFF3DA" stroke-opacity="0.20" stroke-width="1" stroke-linecap="round"/>
      <path d="M79 278.8 h28 M126 278.8 h34 M310 278.8 h39 M432 278.8 h49 M507 278.8 h60 M605 278.8 h28 M669 278.8 h63" stroke="#FFF3DA" stroke-opacity="0.17" stroke-width="1" stroke-linecap="round"/>
      <path d="M296 301.6 h69 M404 301.6 h26 M521 301.6 h73 M610 301.6 h49" stroke="#FFF3DA" stroke-opacity="0.14" stroke-width="1" stroke-linecap="round"/>
      <path d="M156 329.6 h58 M314 329.6 h91 M422 329.6 h26 M479 329.6 h75 M587 329.6 h58" stroke="#FFF3DA" stroke-opacity="0.09" stroke-width="1" stroke-linecap="round"/>
      <circle cx="186" cy="202" r="8" fill="url(#vLamp)" opacity="0.2"/>
      <circle cx="186" cy="202" r="1.7" fill="#FFF3DC" opacity="0.55"/>
      <circle cx="322" cy="201" r="8" fill="url(#vLamp)" opacity="0.2"/>
      <circle cx="322" cy="201" r="1.5" fill="#FFF3DC" opacity="0.55"/>
      <circle cx="540" cy="202.5" r="8" fill="url(#vLamp)" opacity="0.2"/>
      <circle cx="540" cy="202.5" r="1.6" fill="#FFF3DC" opacity="0.55"/>
    </g>

    <g class="v-glint" stroke="#FFE2A6" stroke-linecap="round">
      <path d="M404 201 h56" stroke-width="2" stroke-opacity="0.7"/>
      <path d="M412 207 h40" stroke-width="1.6" stroke-opacity="0.55"/>
      <path d="M418 214 h28" stroke-width="1.4" stroke-opacity="0.42"/>
      <path d="M423 223 h18" stroke-width="1.2" stroke-opacity="0.3"/>
      <path d="M427 234 h10" stroke-width="1" stroke-opacity="0.2"/>
    </g>
    <g class="v-near">
      <circle cx="74" cy="330" r="22" fill="url(#vLamp)" opacity="0.4"/>
      <circle cx="74" cy="330" r="4.3" fill="#FFF6E2" opacity="0.88"/>
      <circle cx="154" cy="302" r="20" fill="url(#vLamp)" opacity="0.4"/>
      <circle cx="154" cy="302" r="4.0" fill="#FFF6E2" opacity="0.88"/>
      <circle cx="238" cy="340" r="21" fill="url(#vLamp)" opacity="0.4"/>
      <circle cx="238" cy="340" r="4.2" fill="#FFF6E2" opacity="0.88"/>
      <circle cx="312" cy="283" r="18" fill="url(#vLamp)" opacity="0.4"/>
      <circle cx="312" cy="283" r="3.6" fill="#FFF6E2" opacity="0.88"/>
      <circle cx="392" cy="314" r="19" fill="url(#vLamp)" opacity="0.4"/>
      <circle cx="392" cy="314" r="3.8" fill="#FFF6E2" opacity="0.88"/>
      <circle cx="470" cy="268" r="16" fill="url(#vLamp)" opacity="0.4"/>
      <circle cx="470" cy="268" r="3.3" fill="#FFF6E2" opacity="0.88"/>
      <circle cx="552" cy="294" r="18" fill="url(#vLamp)" opacity="0.4"/>
      <circle cx="552" cy="294" r="3.5" fill="#FFF6E2" opacity="0.88"/>
      <circle cx="630" cy="256" r="16" fill="url(#vLamp)" opacity="0.4"/>
      <circle cx="630" cy="256" r="3.1" fill="#FFF6E2" opacity="0.88"/>
    </g>

    <path d="M0 196 H680" stroke="#FFF1D2" stroke-opacity="0.72" stroke-width="1.5" fill="none"/>
    <text x="664" y="218" text-anchor="end" font-size="10" letter-spacing="0.13em" fill="#FFF4DE" opacity="0.6">HORIZONTE</text>
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

The eight lights burning in the near ground.

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

The three lights far off at the horizon. Wanted, not blocking a stable
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
