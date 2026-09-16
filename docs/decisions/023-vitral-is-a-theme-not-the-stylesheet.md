---
Date: 2026-09-16
Status: Accepted
Related: ADR 011, ADR 016, ADR 021
Triggers:
  - changing how Janela looks
  - adding a stylesheet, a class or a custom property
  - adding a Stimulus controller to the gem
  - adding a setting
Topics: styling, host-integration, configuration, naming
---

# ADR 023: Vitral Is a Theme, Not the Stylesheet

## Context

ADR 016 gave Janela one stylesheet, deliberately plain: the grid classes
an analyst's numbers choose from, and just enough style that a pane is
legible on install. That was right, and it left an obvious gap. A host
that wants a dashboard to look like something has to write all of it,
and the first thing anyone does with a new library is judge how it
looks.

The temptation is to make `janela.css` prettier. That would be a
mistake. Structure and taste have different lifetimes: the grid classes
are load bearing and must not change, while taste is the first thing a
host will want to replace and the first thing we will want to revise.
Putting both in one file means every visual revision risks the layout,
and every host that dislikes the look has to fight rules it also needs.

## Decision

**A second stylesheet, `vitral.css`, optional and separate.**

A *vitral* is a stained glass window. Janela is a window, its parts are
frames and panes, and this is what the glass looks like. The name
follows the same rule as the rest: an uncommon but conceivable word, so
it never collides with the vocabulary a host already uses for its own
things.

```erb
<%= stylesheet_link_tag "janela" %>
<%= stylesheet_link_tag "vitral" %>
```

Four rules hold it in place.

**Nothing is repainted until asked.** The light and the leading hang off
a `vitral` class. A host that links the stylesheet and adds no class
gets nothing, which means linking it can never be the thing that broke
a page.

**It is a small library, not a private skin.** `vitral-pane`,
`vitral-panes` and `vitral-button` are public, so the page around a
dashboard can be made of the same window. Everything else is a custom
property, so a host rethemes from its own stylesheet rather than by
forking this one.

**The theme must be complete without JavaScript.** Janela's own pages
load none at all (ADR 011), so the stained glass is CSS, and the part
that answers the pointer is a separate optional controller. The
stylesheet carries a static lattice for everyone who never loads it.

**Janela's own pages wear it by name.** `Janela.theme = "vitral"` is the
third setting this gem has, and it earns that the same way the second
did: which theme, if any, is a judgement made once about the whole
application, and that is what configuration is for (ADR 021). A host
that leaves it unset gets the structural stylesheet, exactly as before.

## Consequences

- Janela looks like something out of the box, and a host that hates it
  removes one line rather than overriding a hundred rules.
- `janela.css` can stay frozen and boring while the theme moves. A
  revision to the look is not a revision to the grid.
- The lattice is an inline SVG data URI rather than an image, because a
  stylesheet shipped in a gem cannot rely on a host's asset pipeline to
  resolve a `url()`.
- Accessibility is the theme's problem, not the host's: reduced motion,
  reduced transparency and increased contrast each fall back to a
  still, solid window, and so does a browser without `backdrop-filter`.
- A visual change to vitral is visible to every host that opted in, so
  it belongs in the changelog like any other change a host can see
  (ADR 015). It is not a breaking change, because nothing depends on it.
- A third stylesheet is a third thing for a Sprockets host to declare
  for precompilation. The engine declares both itself.
