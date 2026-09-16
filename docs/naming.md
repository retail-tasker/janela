---
Topics: naming, vocabulary, design, renaming
---

# Naming Things Is Hard

There are two hard problems in computer science, and this page is about
the one that is not cache invalidation. Every name in Janela was chosen
on purpose, several were changed after they shipped, and one rule sits
under all of them.

## The rule

> With words like Janela, Frame and Pane I am purposefully selecting
> uncommon but understandable, conceivable words so that people aren't
> pigeonholed and can select their own nomenclature.

A library that calls its main idea a Dashboard has taken that word from
every application that installs it. Your app probably already has a
`Dashboard`, or a `Report`, or an `Insight`, and whatever you call yours
is the word your users know. So Janela's own vocabulary is deliberately
a step to the side: close enough to understand on first read, unusual
enough that it never collides with the words you already use, and never
the word your users have to see.

That gives two tests for any name in this codebase:

- **Conceivable.** Someone reading it for the first time can guess what
  it is without looking it up.
- **Uncommon.** It is unlikely to already be a model, a table, a route
  or a word on your screens.

## The window

*Janela* is Portuguese for window. The word is the same in Portugal and
in Brazil. Once the library is a window, the rest of its anatomy follows
from the thing itself rather than from a list of synonyms for "chart".

| Name | What it is | Why this word |
| --- | --- | --- |
| **Janela** | The library | A window onto your data. Uncommon in English, obvious once explained. |
| **Frame** | A dashboard: a name and a grid of panes | A window frame holds the panes. It is also what Turbo calls the element that makes cross-filtering work (ADR 003), which is a happy accident rather than the reason. |
| **Pane** | One visual inside a frame, stored as a row | A pane of glass sits in a frame. You look through each one at part of the picture. |
| **Query** | The runtime object that calculates one pane | Not a window word, on purpose. It is an implementation detail rather than something a person arranges, so it gets the plain name for what it does. |
| **Grid** | How a frame is divided: `columns`, `gap`, and each pane's `span` | A window is divided into panes, and the grid is the division. Small integers that choose a class the stylesheet already defines, so nothing an analyst types reaches CSS (ADR 016). |
| **Vitral** | The optional stained glass theme | A stained glass window, in the same language. See ADR 023. |

The anatomy was argued over before it was settled. *Sash* was
considered for the dashboard and rejected: a sash is one layer inside a
window, the moving part that holds glass, and the thing that holds
panes is the frame.

## Words that stay ordinary

Not everything gets an unusual name, and the exceptions follow the same
reasoning.

**Measure and dimension** are the words the business intelligence field
already agreed on. An analyst who has used any tool of that kind knows
exactly what `measure :revenue` and `dimension :region` mean. They are
also method names inside a model's `janela` block rather than classes
sitting in your namespace, so there is nothing for them to collide with.
A domain language should speak its reader's language (ADR 002).

**Snapshot** and **owner** are plain because what they describe is
plain: the numbers frozen at an instant, and whatever a frame belongs
to. Janela assigns an owner and never reads it, so it has no reason to
give it a clever name (ADR 009, ADR 019).

**The doctor** is the conventional name for a command that reads your
setup and tells you what is wrong. Homebrew, Flutter, npm and Bundler
all ship one, so the word already means the right thing (ADR 021).

## Your words, not ours

None of Janela's vocabulary has to reach your users. Two places decide
what they see.

**The noun comes from your locale file.** Every heading the engine
renders uses `Janela::Frame.model_name.human`, so your users read
whatever you call them:

```yaml
en:
  activerecord:
    models:
      janela/frame:
        one: "Report"
        other: "Reports"
```

**The address is wherever you mount it.** Frames live at the mount root
and a pane's URL sits beneath the same path, so the words in the address
bar are yours too:

```ruby
mount Janela::Engine => "/insights"
```

```
/insights                   every frame
/insights/3                 one frame
/insights/orders/revenue    a pane
```

ADR 013 first gave frames a configurable path segment of their own. ADR
014 took it back out, because a segment named `dashboards` or `reports`
is exactly the kind of word a host model already owns, and it shadowed
that model's panes. Keeping Janela's own words out of your URLs turned
out to be the fix as well as the principle.

## One word, one meaning

A single name used for two things is worse than an awkward name, so
some sentences in this codebase are spelled more carefully than they
would be in conversation.

**Frame** on its own always means the dashboard. The HTML element is
always written **turbo frame**, in prose, in comments and in commit
messages, so the two can never be confused.

**Grid** always means a frame's layout, its columns and gap. The lines
drawn between panes by the theme are leading, never grid.

**Pane** always means the stored row. That is why the runtime object
had to give the name up: it was `Janela::Pane` until ADR 014 renamed it
`Janela::Query` so the record could take the word it deserved.

## When a name turns out wrong

Names were changed after release, and each change was treated as
breaking rather than tidied away:

- `janela_dashboard` became `janela_frame`, and the Stimulus controller
  `janela--dashboard` became `janela--frame`.
- `Janela::Pane` became `Janela::Query`, freeing `Pane` for the record.
- `Janela::DashboardHelper` became `Janela::FramesHelper`.

Every one of those is listed in `UPGRADING.md` with the exact
replacement, and `bin/rails janela:doctor` finds any old name left in
your code and names what replaced it (ADR 015). Renaming is allowed. A
rename a user has to discover for themselves is not.

## The look follows the name

The demo and the vitral theme are not decoration picked separately.
Once the library is a window, the design had one obvious direction.

- **The panes are glass.** Each one holds its own colour, and the colour
  cycles by position so a row is never monochrome.
- **The lines between them are leading,** dark and slightly uneven, the
  way lead holds real stained glass. The theme calls its colour
  `--vitral-came`, after the lead strip itself, but that is a styling
  detail to override rather than a word you need to know.
- **The light comes from behind.** Shafts fall from a sun at the top
  right, and hovering the mark fans light through the window, splitting
  into its colours as it comes out the front.
- **The lattice leans toward you.** Its nodes reach for the cursor,
  because a dashboard is meant to respond to the person looking at it.

## Naming something new

If you are adding to Janela or forking it, the same checks apply:

1. Would a stranger guess what it is from the name alone?
2. Is it a word a Rails application is likely to have already?
3. Does it already mean something else in this codebase, or in Rails,
   or in Turbo?
4. Is it something a person arranges, which earns a window word, or an
   implementation detail, which gets a plain one?
5. If you are renaming, have you added it to `UPGRADING.md` and taught
   the doctor to find the old name?
