---
Date: 2026-09-24
Status: Accepted
Related: ADR 001, ADR 009, ADR 012, ADR 016, ADR 036, ADR 037
Triggers:
  - putting a heading, a paragraph, a link, an icon or an image on a stored frame
  - adding a kind of pane that is not a query
  - letting an analyst's text reach a page
  - storing HTML, Markdown or a template in a row
  - deciding whether a frame draws its own name
Topics: frames, panes, persistence, layout, authorisation, html
---

# ADR 039: A Pane Can Hold Words, and Only Code Writes Markup

## Context

ADR 012 made a dashboard data so that its author, the analyst, can
change it without a deploy. It gave the analyst one thing to arrange:
a pane that names a measure the model declared. That was the whole
vocabulary, and it is why a stored frame is safe to hand over. A row
cannot invent a query, reach a model nobody exposed, or put anything on
the page that a developer did not write.

A real dashboard is more than query results. The first one a host asked
about had, above its numbers, a heading with an icon, a count of done
out of total, a percentage, a "view all" link and a progress bar. A
block form frame can have all of it, because the page around the panes
is the host's own ERB (docs/composing.md). A stored frame can have none
of it. `janela/frames/_frame` renders `frame.panes` and nothing else,
and `Janela::Pane` requires a `measure` and validates it against a
`janela` block, so there is no row a heading could be. The frame's
`name` is never drawn either. The analyst who owns the dashboard can
choose every number on it and cannot label them.

So the question is not whether a stored frame should hold content. It
has to, or the frame the analyst owns is always the unlabelled half of
the page. The question is what an analyst may put in a row without
breaking the property ADR 012 was built on.

### What was considered

**Stored HTML**, a column of markup rendered as it is, was rejected.
It is the one thing ADR 012 exists to prevent: an analyst's row would
put arbitrary markup on a page that every other reader of that frame
loads, which is stored cross site scripting with a dashboard for a
delivery mechanism. Running it through Rails' `sanitize` narrows the
tags but not the problem. The allowlist becomes a security boundary
Janela has to maintain, and what survives it, links anywhere and
styling that imitates the host's own chrome, is still content a
developer did not write appearing as if they had.

**Markdown** was rejected for the same reason one step removed. It
compiles to HTML, it needs a parser as a dependency (ADR 001 is spare
with those), and a link in it can point anywhere. What an analyst
actually needs from it, a heading and a paragraph, is two fields.

**A sandboxed iframe**, `<iframe srcdoc sandbox="allow-scripts">`, was
considered because an application built on this gem already renders
agent-authored slides that way, and it works: the sandbox gives the
content an opaque origin, so it cannot read the page or its cookies.
It was rejected for a public gem. The surface is large, the
guarantees depend on attributes a host can loosen, and an iframe does
not size to its content, so it cannot sit in a CSS grid beside a pane
without fixed heights, which is exactly what #24 is trying to remove
for charts. It stays available to any host that wants it, in its own
code, around a frame.

**Drawing the frame's name as a heading** was rejected as the whole
answer. It would change every existing frame's appearance on upgrade,
it gives one heading per frame when a dashboard often wants one per
row, and it still leaves no icon, no paragraph and no link.

**A separate table of content rows** beside `janela_panes` was
rejected because position is the frame's single ordering. Two tables
would need a shared position sequence across them, and ADR 012 kept
one level between a frame and what it shows on purpose.

## Decision

**A pane can hold words instead of a query. An analyst writes text
into a row and Janela escapes it; anything that needs markup is a
partial the host wrote in code, which the analyst places by name.**

This is ADR 012's division of labour applied to content: developers
define what can be shown, analysts arrange it and write the words.

**A pane gains a `kind`.** `query` is today's pane and the default, so
every existing row is unchanged. Two more kinds:

- **`text`**: a `heading`, a `body` and an optional `link`, each a
  plain string. Janela renders the heading as a heading, the body as
  paragraphs split on blank lines, and the link as an anchor, and
  escapes all three. No markup an analyst types reaches the page as
  markup.
- **`partial`**: a `partial` name, plus the same `heading`, `body` and
  `link` passed to it as locals. The partial is the host's, under
  `app/views/janela_content/`, so the host writes the icon, the image,
  the layout and the look, and the analyst writes the words that go in
  it. A name must match `/\A[a-z0-9_]+\z/` and a partial must exist in
  that directory, so a row cannot reach any other template. There is
  no registry and no setting: the directory is the allowlist, the way
  a controller's views directory already is. It sits outside
  `app/views/janela/` on purpose. A host view at an engine's path
  replaces the engine's own, and `janela/panes/` already holds the
  engine's `_form` and `_row`, so a content partial named `form` there
  would silently replace the pane editing form.

```ruby
frame.panes.create!(kind: "text", heading: "Refunds are excluded",
                    body: "Figures are in the store's own currency.")
frame.panes.create!(kind: "partial", partial: "overview_heading",
                    heading: "Project overview", link: "/cards", span: 3)
```

A `text` or `partial` pane has no `model` or `measure`. Those columns
become nullable, and a validation requires them for `query` and
refuses them for the other two, so the database cannot hold a
half-query.

**A link is a path, not a URL.** `link` must start with `/`, and not
`//`, so an analyst can point readers at another page of the same
application and cannot send them to another site. A host that wants an
external link writes it in a partial.

**Images and icons are the host's.** Janela stores no files and ships
no icon set (ADR 036). A heading with an icon is a partial that draws
the icon beside the heading it is given. An image is a partial that
reads it from wherever the host already keeps images. Janela does not
take a dependency on Active Storage to do something a host's own
partial already can.

**A content pane sits in the grid like any other.** It spans columns,
it is ordered by `position`, it is drawn as a `janela-pane`, and under
vitral it is a pane of glass. It does not take part in cross filtering:
it has no query, so the frame controller has no `src` to rewrite, and a
content pane renders inline rather than inside a turbo frame.

## Consequences

- An analyst can label a stored frame, explain it and link out of it
  without a deploy, which is the half of ADR 012 that was missing.
- The property ADR 012 stated plainly still holds, extended: a row can
  name only a declared measure, an escaped string, a same-site path, or
  a partial a developer wrote. Nothing an analyst types is markup.
- `janela_panes` gains `kind`, `heading`, `body`, `link` and `partial`,
  and `model` and `measure` become nullable. That is a migration a host
  has to install, so it needs an `UPGRADING.md` entry (ADR 015). The
  engine's own forms need a way to add each kind.
- The pane partial becomes a branch on `kind`. `_pane.html.erb` is the
  smallest file this touches and should stay that way: one partial per
  kind under `janela/frames/`, chosen by name.
- Snapshots store results, not HTML (ADR 009). A snapshot is a list of
  pane results with no frame behind it, so a content pane has no result
  to store and is not in one. Words that explain a signed off figure
  have to live in whatever page shows the snapshot. If a snapshot ever
  needs to carry the text that sat beside its numbers on the day, that
  is a separate decision.
- The pane class names a theme may target (ADR 036) gain one for the
  content kinds, `janela-content`, and it goes into docs/theming.md in
  the same change.
- Not in 1.0 (ADR 037). It adds to the public surface rather than
  changing it, so it does not block a stable release and can land
  before or after one.
- What would change this decision: a host that genuinely needs an
  analyst to author markup, with a real reason a partial cannot serve.
  The sandboxed iframe is the fallback that case would reopen, and this
  record says why it was set aside.
