---
Date: 2026-10-14
Status: Proposed
Related: ADR 023, ADR 036, ADR 054, ADR 056, ADR 060
Triggers:
  - adding a language to the demo, or a page that is translated
  - generating a route helper for a page under the /pt-BR prefix
  - deciding whether the gem should ship a second language
  - mounting the engine inside a scope with a dynamic segment
  - writing a month, a number or a date label in a chart
Topics: i18n, demo, routing, seo, engines, host-integration, dogfooding
---

# ADR 061: The Demo Speaks Brazilian Portuguese Under a Prefix, and the Gem Stays English

## Context

Janela is the Portuguese word for window, and the demo has never said so in
Portuguese. The maintainer wants a language picker and Brazilian Portuguese
(`pt-BR`) as a homage to the name. Two questions decide the shape: whether the
gem or only the demo carries the language, and where the language lives in the
address.

The README already tells a host to override Janela's words in its own locale
file, and every string the gem shows is one `en.yml` of 63 keys under `janela.*`.

### Measured

Against the demo, 2026-10-14.

**The language can be a prefix, including for the mounted engine.** With the
whole demo inside `scope "(:locale)", locale: /pt-BR/` and the engine mounted
inside it, `/pt-BR/dashboards` serves the engine's index, its frame page and its
editor. Every `href`, `action`, `data-` URL and Turbo Frame `src` on those pages
carries `/pt-BR/`, so cross-filtering stays in the language. `/fr/orders` is a
404, because the constraint admits only the language we have.

**A positional route argument fills the locale slot.** With an optional leading
segment, `doc_path("agents")` generated `locale: "agents"` and then failed for
want of a slug, on every English page, until the controller's
`default_url_options` always carried a `locale` key, nil for English. The same
call in a test outside a request has no controller, so the route set carries
`locale: nil`, which an integration test merges, and the system tests' base class
says it for their own helper object.

**The engine repeated the language as a query parameter.** Its own links came out
as `/pt-BR/dashboards/684?locale=pt-BR`: the mount point already carries the
language in its path, so a `locale` option has nowhere to go but the query
string. `_routes` inside `url_options` says which route set is being generated
for, so the host drops `locale` for the engine's routes and keeps it for its own.

**A month label was English only.** `Dimension::LABELS["month"]` used
`strftime("%b %Y")`, which does not read a locale. A clicked label maps back to
its bucket through a lookup built from the labels (`Query`), not by parsing the
text, so a translated label cannot break a time click.

**Numbers already follow the locale.** The measure reads `number.format` for its
delimiter and `number_to_rounded` for the separator, so with Rails' own Portuguese
data `$375.00` reads `$375,00`.

### What was considered

**The gem ships `pt-BR`.** Rejected for now, by the maintainer. A second language
in the gem is upkeep for every release, and the demo adding it in its own locale
file is the worked example of how any host does.

**A cookie or the `Accept-Language` header.** Rejected. Neither is in the
address, so a link cannot carry the language, a search engine cannot see the
second page, and the visits page promises no cookie.

**A subdomain.** Rejected. It is a second site to certify and deploy for one
language.

**Translating every page.** Rejected as a first step. The guides and decisions are
the gem's own markdown, rendered as they ship (ADR 010), and are English.

## Decision

**English is the root and Brazilian Portuguese is under `/pt-BR`, one address per
language. The gem ships English only, and the demo adds Portuguese in its own
locale files.**

- The pages translated are the home page, the orders dashboard, the visits page,
  the menu, the footer and every string Janela's own pages show. A page that is
  not translated is still reachable under `/pt-BR`, says so at the top, and
  names the English page as its canonical address, so there is never a second
  copy of English text competing with the first.
- A translated page carries `hreflang` alternates for both languages and
  `x-default`. The sitemap lists the translated pages in both. `robots.txt`
  keeps the Portuguese dashboards out as it does the English ones (ADR 060).
- The picker is a link in the menu, named in its own language, that goes to the
  same page in the other language and keeps its filter.
- Brazilian Portuguese for Rails' own words (month names, number formats) is the
  `rails-i18n` gem, in the demo's Gemfile and not the gem's.
- **The gem's month label reads the locale** when the host has month names for it,
  and falls back to English when it has not, so a host that never set a locale
  sees exactly what it did. This is the one change to the gem.
- A frame is `quadro` and a pane is `painel`, the words a Brazilian reader of a
  dashboard already uses, and not the window words (`esquadria`, `vidraça`) that
  are prettier and mean nothing to someone looking for a chart.

## Consequences

- **The Portuguese is written by an assistant and has not been read by a native
  speaker.** It should be before this is shown to people. It is a draft to be
  corrected, and the copy is in two files, so correcting it is an edit.
- **Every `Rails.application.routes` helper in the demo is under an optional
  segment.** A new helper called with a positional argument outside a controller
  needs `locale: nil` or a named argument. The route set and the system test
  base class carry the former.
- **A missing key fails a test.** Test runs raise on a missing translation, and a
  test compares the Portuguese files with the English ones, because fallbacks
  would otherwise hide a gap behind English text.
- **The visits dashboard records Portuguese pages at their own path**, so the
  language a visitor read is visible in the data the demo already shows.
- **What would change this decision:** a host asking for Portuguese from the
  gem, which is the day `config/locales/pt-BR.yml` moves from the demo into the
  gem and `janela.pt-BR.yml` here is deleted.
