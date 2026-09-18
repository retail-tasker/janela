---
Date: 2026-09-19
Status: Accepted
Related: ADR 002, ADR 013, ADR 014, ADR 025, ADR 028
Triggers:
  - subclassing a model that declares a janela block
  - changing what is addressable over HTTP
  - changing how the registry is populated
  - adding to the Ransack allowlist a model gets from Janela
Topics: configuration, urls, security, scope
---

# ADR 031: A Subclass Inherits the Dashboard Its Parent Declared

## Context

`janela` stores its definition in a plain class instance variable, so a
subclass of a model that declares one gets `nil` from `.janela` and is
not in the registry (#11).

Reproducing it found something the issue did not say. The subclass does
inherit the Ransack allowlist, because
`define_janela_ransack_allowlist` defines singleton methods on the
parent and singleton methods inherit down the singleton class chain:

```
subclass .janela:      nil
subclass ransackable:  ["status", "channel", "placed_on"]
```

So a subclass is already half declared: filterable on the parent's
dimensions, with no definition behind it saying what those dimensions
are. Neither half was decided. One was written and the other happened.

The instinct is to walk the ancestors in `janela`, which fixes `.janela`
and does not fix the bug. What a host wants from an STI subclass is a
dashboard of it, and that needs the subclass registered:

```ruby
janela_pane PaidOrder, :revenue   # src is /paid_orders/revenue
```

An inherited definition with no registration renders that pane and then
404s it. That is worse than today, because today the failure is loud at
the call site and that one is a dead pane on a page.

So the question is not whether the definition inherits. It is whether
being a subclass makes a model addressable, and `lib/janela.rb` states
the current answer plainly:

> Only models that declare a janela block are addressable over HTTP

## Decision

**A subclass inherits its parent's definition and is addressable on its
own route key. Declaring is what a family of classes does once.**

The argument that settles it is about data rather than URLs. An STI
subclass is a subset of its parent's rows. If the parent is addressable,
the subclass reveals no row the parent does not already total, and it is
read through the same host scope as everything else (ADR 014). So this
adds URL surface and no data surface, which is a much smaller thing than
the rule above makes it sound.

Three things follow.

1. **The halves agree.** The definition inherits, the registration
   inherits, and the Ransack allowlist keeps inheriting as it already
   does. A subclass is either a Janela model or it is not, rather than
   being one in the part nobody chose.
2. **STI scoping is ActiveRecord's, not Janela's.** A definition whose
   model is the subclass runs its query on that class and ActiveRecord
   adds the `type` condition itself. Janela learns nothing about STI,
   which is the right amount for it to know.
3. **A subclass may still declare its own block**, and then it has its
   own definition rather than its parent's, which is how a subclass says
   its dashboard is different.

Registration cannot happen where declaration happens, because the
subclass does not exist when the parent declares. It happens when the
subclass is created.

## What this turns down

**Inheriting nothing, and documenting that each subclass declares its
own.** It is the most conservative reading and it asks a host with five
STI types to retype the same measures and dimensions five times. ADR 002
spent Ransack's familiarity on the host deliberately; spending their
typing on a class hierarchy Rails already models is a worse trade.

**Inheriting the definition without registering.** Rejected above: a
helper that renders a pane which cannot load.

## Consequences

The honest cost is not security, it is noise. `Janela.definitions` feeds
the form that offers a choice of model when an analyst adds a pane
(ADR 012), and a host with a dozen STI types will see a dozen entries
where it expected one. That is a real cost and it is the thing to watch:
if it becomes the complaint, the answer is a way for a family to say
which of its classes are worth offering, and that is a later decision
rather than a setting invented now.

The check on whether this decision is right is what a host writes. If
adding a dashboard for an STI subclass still takes anything beyond
creating the class, the decision did not deliver.

The demo has no STI model, so proving this takes one: a `type` column on
a table and a subclass in the dummy. That is a fixture, and adding it is
part of the work rather than a reason to avoid it.
