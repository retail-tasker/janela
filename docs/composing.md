---
Topics: composing, html, layout, host-integration, styling
---

# Composing a Page Around Panes

A pane is a number, a table or a chart. Everything a dashboard has that
is not a query result, the heading, the icon beside it, a sentence of
explanation, a link to the full list, a progress bar, is ordinary HTML
that your application writes. This page is the reference for writing it
so that it sits properly beside Janela's own markup.

The short version: compose with the block form of `janela_frame`, put
your markup and the panes inside a `janela-frame` grid, and style both
with your own classes plus the hooks in [Theming Janela](theming).

## Where your markup can go

`janela_frame` has two forms, and only one of them takes your HTML.

| Form | Your own HTML | Use it when |
| --- | --- | --- |
| `janela_frame do ... end` | anywhere inside the block | the page needs a heading, text, links or a layout of its own |
| `janela_frame @frame` | none | the dashboard is data an analyst edits without a deploy |

A stored frame renders panes and nothing else. That is deliberate (ADR
012): a row names a measure the model declared, so an analyst arranges
what is shown and cannot put arbitrary content on the page. If a
dashboard needs a heading and an explanation, write them in the page
around the frame, or use the block form. Whether a stored frame should
hold content of its own, such as text or an image, has not been decided.

```erb
<h2>Orders</h2>
<p>Everything placed this financial year.</p>
<%= janela_frame @frame %>
```

Inside the block form, anything goes. The block's own `<div>` carries
the cross-filtering controller, so a button or a link inside it can
clear or re-point the panes, and markup that has nothing to do with
filtering is simply ignored by it.

## The grid

The block form's wrapper is not a grid. Write the grid yourself with the
same classes a stored frame gets from its integers:

```erb
<%= janela_frame do %>
  <div class="janela-frame janela-cols-3 janela-gap-4">
    <%= janela_pane Order, :revenue %>
    <%= janela_pane Order, :orders %>
    <%= janela_pane Order, :average_order %>
  </div>
<% end %>
```

Every direct child is a grid item, your own elements included, so a
heading can take a whole row and a text box can sit between two panes.
`janela_pane` takes no class of its own yet
([#29](https://github.com/retail-tasker/janela/issues/29)), so wrap a
pane to span it:

```erb
<div class="janela-span-2"><%= janela_pane Order, :revenue, by: :status, as: :bar %></div>
```

Below `40rem` the grid is one column whatever you asked for.

Under the vitral theme every direct child of `janela-frame` is drawn as a
pane of glass, your heading and your notes included. That is usually
what you want, since the page reads as one window. When it is not, put
the element above the grid rather than in it.

## A frame for one record

One frame is often wanted on every record's page, each copy narrowed to
its own record. Pass the condition as `where:` and every pane is
filtered by it before anything the reader selects:

```erb
<%= janela_frame @frame, where: { queue_id_eq: @queue.id } %>
```

The block form takes the same argument. Do not carry the record in the
page URL's `q[...]` instead: that is the reader's selection, and Clear
filters or Escape takes it off. `where:` is a view filter, not a
permission, so a record a reader must not see is kept out of reach by
your `policy_scope` (ADR 040). Do not also offer the fixed dimension as a
pane the reader can click: any value but the fixed one returns nothing.

A figure you compute yourself for the same page, such as the progress
bar below, takes the same condition in its own `where:`.

## Components

Each of these is plain HTML. The class names that start `janela-` are
the contract and will not change without an entry in `UPGRADING.md`.
The ones that do not are yours to name; the examples use a `card-`
prefix only so they read clearly.

### A heading with an icon

A heading belongs to your page, not to a pane. Make it a full-width grid
item so it sits above the panes it introduces.

```erb
<%= janela_frame do %>
  <div class="janela-frame janela-cols-3 janela-gap-4">
    <header class="janela-span-3 card-heading">
      <svg aria-hidden="true" class="card-icon">...</svg>
      <h2>Orders overview</h2>
    </header>
    <%= janela_pane Order, :revenue %>
    ...
  </div>
<% end %>
```

Mark the icon `aria-hidden="true"`. The heading's text is its name, and
an icon read aloud as "image" adds nothing.

### A text box

Explanation, a caveat, what the numbers exclude. A grid item like any
other, so it can span the row or sit beside a pane.

```erb
<p class="janela-span-3 card-note">
  Refunds are excluded. Figures are in the store's own currency.
</p>
```

Write it in the page rather than in a pane's title. A title is the
pane's accessible name and should say what it measures, not carry a
paragraph.

### A labelled number

A single value pane already renders its own label and number
(`janela-value-label`, `janela-value-number`). When your card already
says what the number is, hide the pane's label with
`janela-own-headings` so it is not on screen twice. It stays in the
accessibility tree.

```erb
<div class="card janela-own-headings">
  <p class="card-label">Revenue</p>
  <%= janela_pane Order, :revenue %>
</div>
```

### Several numbers in one card

Two single value panes side by side read as one figure. Each is its own
query, so each cross-filters on its own.

```erb
<div class="card janela-own-headings">
  <p class="card-label">Revenue, from orders</p>
  <div class="card-figure">
    <%= janela_pane Order, :revenue %>
    <span>from</span>
    <%= janela_pane Order, :orders %>
  </div>
</div>
```

```css
.card-figure { display: flex; align-items: baseline; gap: .5rem; }
```

A single value pane is a block of its own, a `<p>` holding its label
and number, so the figure needs a `<div>` rather than a `<p>` around it,
and a line of CSS to put the numbers side by side. Without it they
stack.

A done out of total figure cannot be two panes yet. A measure has no
condition of its own, so there is no pane for the done half. Compute it
as the progress bar below does. A measure that is itself the ratio is
proposed in ADR 038
([#27](https://github.com/retail-tasker/janela/issues/27)).

### A progress bar

There is no progress renderer. A bar is your own markup, from a value
your controller computes through the same scope Janela uses.
`where:` takes the same Ransack conditions a pane's filters do, on the
dimensions the model declared:

```ruby
scope = policy_scope(Order)
done = Order.janela.query(:orders, where: { status_eq: "paid" }, on: scope)
total = Order.janela.query(:orders, on: scope)
@percent = total.zero? ? 0 : (100.0 * done / total).round
```

```erb
<div class="janela-span-3 card-progress">
  <p><span>Paid</span> <span><%= @percent %>%</span></p>
  <progress max="100" value="<%= @percent %>"><%= @percent %>%</progress>
</div>
```

Use `<progress>` rather than two nested `<div>`s: it has a role and a
value a screen reader can announce without any ARIA of your own. It is
computed once, when the page renders, so it does not move when a click
cross-filters the panes around it. Put it outside the frame, or say
that it is the unfiltered figure, so nobody reads it as filtered.

### A link or an action

A link to the full list, or a button that clears the filters.

```erb
<%= link_to "View all", orders_path, class: "card-link" %>
<button type="button" data-action="janela--frame#clear">Clear filters</button>
```

A button only reaches `janela--frame` from inside the block. Outside
it, it has no frame to clear.

## Putting it together

An overview card: a heading with an icon and a link, two numbers and a
note, then a progress bar under it.

```erb
<%= janela_frame do %>
  <div class="janela-frame janela-cols-3 janela-gap-4">
    <header class="janela-span-3 card-heading">
      <svg aria-hidden="true" class="card-icon">...</svg>
      <h2>Orders overview</h2>
      <%= link_to "View all", orders_path, class: "card-link" %>
    </header>

    <div class="janela-span-2 card janela-own-headings">
      <p class="card-label">Revenue, from orders</p>
      <div class="card-figure">
        <%= janela_pane Order, :revenue %>
        <span>from</span>
        <%= janela_pane Order, :orders %>
      </div>
    </div>

    <p class="card-note">Refunds are excluded.</p>
  </div>
<% end %>

<div class="card-progress">
  <p><span>Paid, across every order</span> <span><%= @percent %>%</span></p>
  <progress max="100" value="<%= @percent %>"><%= @percent %>%</progress>
</div>
```

The progress bar sits below the frame, and its label says it covers
every order, because it does not move when a click filters the panes
above it.

## What this page is not

It is not a component library. Janela ships no `card` class and will
not: a heading, a paragraph and a link already exist, and your
application already has a way of drawing them. What Janela promises is
the grid and the pane hooks, so that your markup and its markup can sit
in one layout. If a component keeps needing something from a pane that
the hooks cannot give it, that is worth an issue rather than a
workaround.
