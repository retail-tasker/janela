---
Date: 2026-09-29
Status: Accepted
Related: ADR 003, ADR 005, ADR 006, ADR 008, ADR 018, ADR 024, ADR 025, ADR 037, ADR 040
Triggers:
  - making a line chart, or a time table row, a click source
  - a click that has to write more than one filter condition
  - deciding what a time pane does with a range filter on its own dimension
  - writing a time range into the page URL or a pane src
  - drill-down, or narrowing a time pane's granularity by clicking a bucket
Topics: time, cross-filtering, urls, ransack, accessibility, roadmap
---

# ADR 045: Clicking a Time Bucket Filters the Frame to Its Range

## Context

A time pane re-scopes when any other pane is clicked, but clicking a
bucket in it does nothing (#18). ADR 006 left that out deliberately:
"Clicking a category adds one Ransack condition, `status_eq=paid`.
Clicking a month means two, `placed_on_gteq` and `placed_on_lt`, and the
dashboard's filter model is a single key and value per toggle." It said
drill-down was the natural next decision and would get its own ADR. This
is that ADR, and it comes now rather than after 1.0 because of what ADR
037 says 1.0 is: the pane URL shape and the dashboard filter parameters
stop moving. A range is a new shape in exactly that grammar, and adding
it after the freeze is a breaking change to the surface rather than an
addition to it. Nobody reading a dashboard would call a line chart that
ignores clicks finished, either. It is the first pane a person tries to
click.

Four things were measured against the dummy before deciding anything.

**Two conditions work as a range, and the end is exclusive.** Against the
`placed_on` date column, `placed_on_gteq=2026-09-01` with
`placed_on_lt=2026-09-02` returns the one order on that day, of four in
all. The month equivalent returns all four. `_gteq` and `_lt` are
already on a time dimension's allowed list (ADR 025), so the guard needs
nothing added. Using `_lteq` for the end would make the end of one bucket
also the start of the next, which is why the pair is half open.

**A bucket's label cannot be turned back into a range.** Groupdate's keys
are labelled after the query (ADR 006): a day is `2026-09-01`, a week is
its Monday `2026-08-31`, but a month is `Sep 2026`, a quarter is
`Q3 2026` and a year is `2026`. The chart looks its filter up by label
(`filters_for`), so the range has to be computed on the server from the
bucket before the key is turned into a label, not parsed out of the label
afterwards.

**A time pane collapses to the bucket that was clicked.** `Query
#applicable_filters` drops a categorical pane's own dimension from its
filters, so the pane still shows the alternatives to what was picked, but
returns every filter for a time pane. With a range on `placed_on`, the
time pane's own query returns `{"2026-09-01" => 1}`: one point on a line.
That is the whole difficulty. If the click wrote the range and nothing
else changed, the pane you clicked would become a single dot, and so
would every other time pane over the same dimension.

**A time zone offset is accepted on a date column.** `2026-09-01T00:00:00Z`
and `2026-09-01T00:00:00+10:00` both filter the date column to the right
day, in UTC and under `Australia/Brisbane`. Not measured, because the
dummy has no time dimension on a timestamp column and `created_at` is not
ransackable there: the same pair against a datetime column with
non-UTC `Time.zone`. Whoever builds this checks it first (see
Consequences).

### What was considered

**Write one key, a range string.** `placed_on_between=2026-09-01..2026-09-02`
would keep the frame's one key and value per toggle. Rejected. Ransack
has no such predicate, so it would be a grammar Janela invents on top of
ADR 005's, which is built on `q[...]` a person can read and a host can
already write by hand (ADR 025). ADR 002 and CLAUDE.md are both against a
second query language, and ADR 006 already tells hosts they can pass
`placed_on_gteq` and `placed_on_lt` today.

**Have the click write keys of its own, so it never meets the host's.**
A `placed_on_clicked_from` pair, say, that a time pane ignores while it
keeps applying `_gteq` and `_lt`. Rejected as a second vocabulary for one
idea. The reader's own selection and a host's range are different
*sources*, and ADR 040 and ADR 043 already sort by source: a host's fixed
and default filters apply on a pane's own dimension, the reader's do not.
Time panes should follow that rule like every other pane, not carry a
private one.

**Narrow, the way a BI tool drills.** Clicking `Sep 2026` changes that
pane's granularity to weeks within September (#18's second option).
Rejected here, and deferred, not refused. It changes what one pane shows
rather than what the frame is filtered to, so it is a separate gesture
with its own question: how to get back out, and whether it belongs in the
URL (ADR 008). The filter is useful alone, and drill-down can be added
on top of it without changing anything decided below.

**Select more than one bucket.** Ctrl-click to add a second day, as ADR
024 does for values. Rejected. Two `_gteq`/`_lt` pairs on one attribute
are not two ranges. Ransack ANDs its conditions, so two different days
return no rows at all, silently, which is the failure ADR 024 measured for
`_null` with `_in`. Ransack's `g[]` grouping could express an OR and is
rejected for the reason ADR 024 gave: it makes the URL unreadable.
Adjacent buckets could be merged into one longer range, but that is a
different gesture with a different rule about gaps, and nothing here asks
for it.

## Decision

**Clicking a bucket on a time pane filters the frame to that bucket's
half-open range, written as the dimension's `_gteq` and `_lt`. A time
pane shows the alternatives to its own selection, like every other pane,
and highlights the buckets inside it.**

**The range is the bucket's start and the next bucket's start.** The
server computes both from the bucket Groupdate returned, at the pane's
granularity and with the week starting on `Date.beginning_of_week`, and
hands the chart a pair per label. A click on `Sep 2026` writes:

```
q[placed_on_gteq]=2026-09-01&q[placed_on_lt]=2026-10-01
```

For a date column the values are dates. For a timestamp they are the
start in `Time.zone`, ISO 8601 with its offset, so the bucket a person
clicked is the bucket the filter selects. The URL stays readable and
editable, and a range a host passes by hand behaves identically.

**The toggle carries a selection, and a selection can be more than one
condition.** A value click is a selection of one condition, as it is
today. A bucket click is a selection of two. The frame controller treats
either as one thing to add, replace or clear, so `clearDimension` clears
the dimension's `gteq`, `gt`, `lteq` and `lt` as well as `in`, `null` and
`eq`. Clicking the selected bucket clears it, the same as a value.

**A modifier click is a plain click on a time pane.** A range is not a
set, for the reason above, so Ctrl and Cmd change nothing here. This is
the one place ADR 024's gesture does not apply, and the pane says so in
its accessible description rather than leaving it to be discovered.

**A time pane ignores the reader's range on its own dimension, and
highlights the buckets that fall inside it.** This reverses what
`applicable_filters` does for time panes today and follows the rule ADR
040 and ADR 043 already set: a host's fixed and default filters narrow a
pane on its own dimension, the reader's selection does not. A bucket is
selected when its whole range lies within the filter's, so clicking a
month highlights every day of that month on a day chart. Panes over the
same dimension at different granularities agree that way without knowing
about each other.

**Granularity does not change.** Drill-down stays open (#18's second
option), to be decided on top of this rather than folded into it.

**Keyboard follows ADR 018.** A time table's rows render their labels as
buttons, as a categorical table's do, and Enter is the click. A line
chart stays a mouse surface, as ADR 024 accepts for bars, and the table
that renders the same data is the operable one.

**A stored pane is still not clickable** (ADR 009). It is the record of a
moment.

## Consequences

- A dashboard can answer "what happened in March?" by clicking March,
  and every other pane re-scopes. That is the first thing anyone tries on
  a line chart and it now works.
- **Breaking, narrowly.** A reader-supplied `placed_on_gteq` or `_lt` in a
  URL used to narrow a time pane's own series. It now scopes every other
  pane and leaves that one showing the whole series with the range
  highlighted. A host's `where:` and `default_where` still narrow it, so
  the supported way to fix a range is unchanged. It needs an
  `UPGRADING.md` entry naming both routes, and the release carrying it is
  a minor one (ADR 015). The doctor cannot see this from source, because
  the filter arrives at runtime.
- `Query#clickable?` stops excluding time panes, `filter_params` and
  `filters_for` return a pair for one, and `selected_values` for a time
  pane becomes a question about ranges. `Definition#query` has to keep the
  bucket start until after the labelling step, since the label is
  lossy. These are the parts a forker is most likely to touch, and the
  reason they are named here.
- The frame controller's toggle grows from one key and value to a
  selection. A host that dispatches `janela--frame:toggle` itself keeps
  working, because a single key and value is still a selection.
- The case measured in Context as unmeasured was measured in the build.
  On SQLite under `Australia/Brisbane`, a timestamp at 14:30 UTC on 1
  September was bucketed into 2 September, a `_gteq`/`_lt` pair written as
  ISO 8601 with `+10:00` for 2 September returned it and the pair for 1
  September returned nothing, and date-only strings gave the same answers.
  Groupdate honoured the zone on SQLite there, which ADR 006 said it does
  not, so that line of ADR 006 is out of date. Not measured on PostgreSQL
  or MySQL, whose zone handling is the database's own.
- **The demo proves it.** Until a line pane on the home page's "This one
  is live" frame filters the other panes when a day is clicked, and a
  system test does the same, this ADR has been read but not shown to work.
  The build includes both, and the home page's copy changes from "three
  panes" to match.
- **This moves #18 into 1.0.** ADR 037 sorted #18 after 1.0 on the ground
  that it "needs an ADR of its own before any code", and that ADR now
  exists. What moves it is the ground ADR 037 itself argues: a range is a
  new shape in the URL grammar the freeze covers. The milestone gains a
  ninth issue, `docs/roadmap.md` (and the count in its illustration) is
  updated with it, and ADR 037 is left as written. The sort in it was
  right at the time, and an ADR records what was decided then.
- ADR 006's paragraph "Time panes are not yet click sources" is
  superseded by this one. The rest of ADR 006 stands.
- What would change this decision: a real dashboard that needs two
  separate periods selected at once, which would have to be an OR and
  would have to justify the URL cost ADR 024 refused; or drill-down
  turning out to be the gesture people expect from a click, in which case
  the follow-up ADR may swap which one a plain click does.
