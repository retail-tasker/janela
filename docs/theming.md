---
Topics: styling, theming, css, host-integration
---

# Theming Janela

Janela publishes the hooks; a theme supplies the taste. This page is the
contract: the class names and custom properties the engine renders, which
your own stylesheet or somebody else's theme may target, and which will
not change without an entry in `UPGRADING.md` (ADR 036).

Two stylesheets ship in the gem.

```erb
<%= stylesheet_link_tag "janela" %>   <%# the hooks, and enough style to be legible %>
<%= stylesheet_link_tag "vitral" %>   <%# optional: one theme, stained glass %>
```

`janela.css` is not a look. It is the grid, the pane's own markup and
enough base styling that a table does not run its label into its number.
Everything decorative is a theme's, and vitral is one theme rather than
the theme.

## The contract

### Custom properties

Setting any of these moves everything that depends on it.

| Property | Default | What it does |
| --- | --- | --- |
| `--janela-space` | `0.25rem` | The base unit of the whole spacing scale. Every gap and padding is a multiple of it. |
| `--janela-line` | `rgba(128, 128, 128, 0.3)` | Rules between rows, borders on cards and fields. |
| `--janela-accent` | `rgb(54, 162, 235)` | A selected value, a hovered card, a line chart (#62), and the first colour of the palette below. |
| `--janela-series-1` to `--janela-series-8` | the accent, then `#eb6834`, `#1baf7a`, `#eda100`, `#e87ba4`, `#008300`, `#4a3aa7`, `#e34948` | The colour a bar, a doughnut slice or a pie slice is drawn in, by its position in the pane, first to eighth (ADR 046). |
| `--janela-series-other` | `#8c8c8c` | Every position after the eighth. The palette is never cycled, so the ninth value is not drawn like the first. |

```css
:root {
  --janela-space: 0.3rem;
  --janela-accent: #7c3aed;
}
```

### The grid

A frame's stored integers choose these. Nothing an analyst types reaches
CSS as a length: the number selects a rule that is already written
(ADR 016).

| Class | Range |
| --- | --- |
| `janela-frame` | the grid container itself |
| `janela-cols-N` | 1 to 12 |
| `janela-gap-N` | 0 to 8, multiplied by `--janela-space` |
| `janela-span-N` | 1 to 12, on a pane |

Below `40rem` the grid collapses to one column. That is in the
stylesheet rather than in the data, because a dashboard nobody can read
on a phone is not a choice worth offering.

### The pane

What `janela_pane` and `janela_frame` put in your own pages. These are
the names a theme spends most of its time on.

| Class | On | Rendered when |
| --- | --- | --- |
| `janela-pane` | `<table>`, `<p>`, `<figure>` or `<div>` | every pane, whatever the renderer |
| `janela-value` | `<p>` | a single value pane |
| `janela-fact` | `<th>`, `<td>` | a table's companion column that is a dimension's shared fact rather than a number, so it is set left. A table with companions also has a `<thead>`; without them it has none (ADR 051) |
| `janela-value-label` | `<span>` | its caption |
| `janela-value-number` | `<strong>` | the number itself |
| `janela-prominence-1` to `janela-prominence-3` | `<p>` | on a single value that declares how prominent it is: the number is `1.25rem`, `2rem` or `3.5rem`. Step 2 is what a value is without the class (ADR 050) |
| `janela-chart` | `<canvas>` | a bar or line pane, inside its `<figure>` |
| `janela-chart-title` | `<figcaption>` | its caption (ADR 042) |
| `janela-chart-box` | `<div>` | around the canvas of a bar or line pane that has a height; a pane without one has no box |
| `janela-h-1` to `janela-h-5` | `<div>` | the box's height, in steps of the spacing unit: 24, 40, 56, 80 and 112 times `--janela-space`, so 96, 160, 224, 320 and 448px by default (ADR 047) |
| `janela-ring` | `<figure>` | a doughnut or pie pane (ADR 046) |
| `janela-ring-svg` | `<svg>` | its picture; `data-hole` is `true` for a doughnut |
| `janela-ring-slice` | `<path>` | one slice; `janela-dim` is added to those not selected while something is |
| `janela-legend` | `<table>` | its legend, one row of swatch, button and value per slice |
| `janela-swatch` | `<span>` | the colour beside a legend label |
| `janela-empty` | `<p>` | a pane whose query returned nothing |
| `janela-error` | `<p>` | a pane that could not be read |
| `janela-content` | `<div>` | a stored pane holding words or a host partial rather than a query (ADR 039) |
| `janela-content-heading` | `<h2>` | a text pane's heading |

The dark values that passed the palette check on a dark surface are
`#3987e5`, `#d95926`, `#199e70`, `#c98500`, `#d55181`, `#008300`,
`#9085e9` and `#e66767`. `janela.css` ships no dark scheme (ADR 023), so
a dark theme sets the eight properties to them.

A table pane renders a `<caption>` and a chart pane a `<figcaption>`,
each its own accessible name; the chart's canvas points to its
figcaption with `aria-labelledby` rather than repeating the string in
`aria-label`, so the two cannot drift apart (ADR 042).

### Hiding a heading you already wrote

Put `janela-own-headings` on any ancestor and a table's caption, a
single value's label and a chart's title are hidden from sight while
staying in the accessibility tree.

```erb
<div class="janela-own-headings">
  <h3>Revenue by status</h3>
  <%= janela_pane Order, :revenue, by: :status %>
</div>
```

Use it when your own markup already says what the pane is, so the text
is not on screen twice. It hides rather than removes on purpose: a pane
with no visible caption still needs its accessible name, so a screen
reader lands on a grid of numbers with nothing to say what they
measure. `display: none` would do that, which is why this rule ships
here rather than being left for each host to write.

## What is not the contract

`janela.css` also styles Janela's own pages, the frame index and the
editing forms: `janela-page`, `janela-card`, `janela-button`,
`janela-form`, `janela-field`, `janela-list`, `janela-crumb`,
`janela-flash` and the rest. They are scoped under `janela-page`, which
only the engine's own layout sets, so they cannot touch your pages.

**Those names may change in any release.** They are the engine's own
chrome rather than an interface. Restyle them if you want Janela's
pages to match your application, and expect to revisit it after an
upgrade; or point `Janela.theme` at a stylesheet of your own, below.

## Writing a theme

A theme is any stylesheet, named once:

```ruby
# config/initializers/janela.rb
Janela.theme = "midnight"
```

The name is resolved against your own asset paths, so `midnight.css` in
your application works exactly as the gem's own `vitral` does. A name
that resolves to nothing raises rather than quietly rendering an
unthemed page.

That setting links the theme into **Janela's own pages**. Your pages load
whatever your layout says, so if you want the same look around a pane you
have embedded yourself, link the stylesheet there too. The asymmetry is
deliberate: Janela is an isolated engine and does not write your layout
(ADR 011).

A theme targets the contract above and nothing else. If it cannot be
written that way, the contract is missing something, which is worth an
issue rather than a workaround.

## Vitral

The theme the gem ships. A *vitral* is a stained glass window: each pane
holds one of five colours, dark leading runs between them, and the light
comes from behind.

```erb
<%= stylesheet_link_tag "vitral" %>
<body class="vitral">
```

Nothing is repainted until that class is present, so linking the
stylesheet can never be the thing that broke a page.

**Its own public classes**, so the page around a dashboard can be made of
the same window: `vitral-pane`, `vitral-panes`, `vitral-button`,
`vitral-button-primary`, `vitral-lattice`.

**Retheme it from its custom properties** rather than by forking it. The
light is `--vitral-light-cobalt`, `-teal`, `-amber`, `-rose`, `-violet`;
the glass is `--vitral-pane-1` through `-5`; the leading is
`--vitral-came`; and `--vitral-ink`, `--vitral-muted`, `--vitral-ground`,
`--vitral-radius`, `--vitral-shadow` and `--vitral-blur` do what they
say.

```css
:root {
  --vitral-pane-1: rgba(120, 60, 200, 0.3);
  --vitral-came: #1b1b1b;
}
```

**It works without JavaScript.** Janela's own pages load none (ADR 011),
so the stained glass is CSS and the lattice that leans toward the pointer
is a separate optional controller. Reduced motion, reduced transparency
and increased contrast each fall back to a still, solid window, and so
does a browser without `backdrop-filter`.

`test/dummy` has a live page at `/vitral` showing all of it against real
panes.
