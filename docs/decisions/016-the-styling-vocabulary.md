---
Date: 2026-09-16
Status: Accepted
Related: ADR 001, ADR 012, ADR 014
Triggers:
  - adding or renaming a CSS class the engine renders
  - adding a layout value a person can edit
  - changing the spacing scale or the grid
  - a host asking how to restyle Janela
Topics: css, layout, styling, public-api, security
---

# ADR 016: The Styling Vocabulary

## Context

ADR 012 made a frame's layout data: how many columns, what gap, how
many columns a pane spans. ADR 014 confirmed the vocabulary is CSS
Grid's rather than a new glossary. Two things still had to be decided
before any of it is rendered.

The first is safety. These values are edited by an analyst, and a
length like `1rem` interpolated into a style attribute is injectable:
`1rem; position: fixed; top: 0` is valid CSS and escaping does not
help inside an attribute. The field is harmless today only because
nobody can type into it yet, which changes in build 4.

The second is that Janela ships no CSS at all, so a table pane renders
with no padding and a label runs into its number, reading as `false55`
(issue #15). A grid means nothing without CSS, so the stylesheet stops
being optional the moment frames exist.

Tailwind is the obvious model, and the part worth taking is not
utility classes but the reason they work: the scale is **finite and
indexed rather than measured**, so an inconsistent design is not
expressible.

## Decision

**Layout values are small integers, and the gem supplies the units.**
`columns` 1 to 12, `gap` 0 to 8, `span` 1 to 12. An integer cannot
inject anything, so the field is safe by construction rather than by a
regular expression somebody has to keep trusting.

**An integer selects a class; it is never interpolated into a style
attribute.** The engine renders class names and the shipped stylesheet
defines them:

```css
.janela-frame     { display: grid; }
.janela-cols-3    { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.janela-gap-4     { gap: calc(var(--janela-space) * 4); }
.janela-span-2    { grid-column: span 2; }
```

Around thirty rules, enumerated for every value the validations
permit. Nothing an analyst supplies reaches CSS: the integer only
chooses a rule that was already written.

**One naming rule: `janela-{property}-{scale}`.** `janela-cols-3`,
`janela-gap-4`, `janela-span-2`. Learn it once and the rest is
predictable, which is doing more work in Tailwind's success than any
individual class.

**One base unit is the whole spacing theme.** `--janela-space`,
defaulting to `0.25rem`. A host sets it once and the entire scale
moves, without touching data or overriding rules.

**Responsive behaviour is in the stylesheet, not in the data.** The
grid collapses to a single column below a narrow breakpoint. An
analyst chooses a column count, not a set of breakpoints, and a
dashboard that is unreadable on a phone is not a choice worth
offering. Per breakpoint control, if ever needed, is a separate
decision.

**No arbitrary value escape hatch.** Tailwind offers `gap-[17px]`
because a developer occasionally has to defy the design system. Here
the editor is an analyst, the constraint is the point, and an escape
hatch reintroduces exactly the injection surface these integers close.

**The class names are public API.** A host restyles Janela by
overriding `.janela-pane`, `.janela-gap-4` and the rest, or by setting
`--janela-space`, so renaming one is a breaking change and belongs in
`UPGRADING.md` like any other (ADR 015). The stylesheet ships as
`app/assets/stylesheets/janela.css` and a host includes it, rather
than the engine injecting it into a layout it does not own.

## Consequences

- Issue #15 is answered: the gem ships CSS, so a pane is legible on
  install, and a host overrides rather than writes from scratch.
- An analyst cannot express `1.375rem` of gap. Intended: the realistic
  choices are none, small, medium and large, and a finite scale is why
  a dashboard built by several people still looks like one thing.
- The enumerated rules must stay in step with the validation ranges.
  A value that validates but has no class renders unstyled and
  silently, so the test suite asserts the two agree.
- Janela now owns a stylesheet, which is a surface it has to maintain
  and a thing hosts will want to argue with. Custom properties are
  the pressure valve: retheme without forking.
