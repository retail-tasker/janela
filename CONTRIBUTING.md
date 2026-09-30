# Contributing to Janela

Bug reports and pull requests are welcome. A pull request is reviewed on the
merits of the diff, whether a person or an agent wrote it (ADR 001). Please
follow the [code of conduct](CODE_OF_CONDUCT.md).

Janela is meant to stay small enough to read start to finish in one sitting, and
to fork. Prefer the change that removes a choice over the one that adds a setting.

## Before you write code

- **Look for the decision.** [`docs/decisions/INDEX.md`](docs/decisions/INDEX.md)
  maps every architecture decision record by topic. If your change touches an
  area an ADR covers, read it first. If it would contradict one, it needs a new
  ADR that supersedes it, and preference alone is not a reason.
- **Open an issue for anything that changes what a host sees.** A new DSL word,
  a pane URL parameter, a class name a theme targets, a column on a table, a
  changed default. These are the public surface, and after 1.0 they change only
  in a major release. An issue labelled `needs-adr` waits for a decision before
  code; one labelled `ready` can be built.
- **Nothing about a host application belongs here.** Janela is standalone.
  No host's model names, table shapes or business logic in code, tests or prose.

## Making the change

```bash
bundle install
bundle exec rake            # unit tests and RuboCop
bundle exec rake system     # the browser suite; needs Chrome
```

- **Test first, and read the failure.** A test that fails for a typo is not
  evidence. Where a belief turned out false, say so in a comment on the test, so
  it isn't deleted as redundant.
- **Browser tests for anything with Turbo, Stimulus, a chart or a click.** A
  number rendered by the server proves nothing about the JavaScript.
- **Ruby 3.3 is the floor**, so no `it` block parameter. CI runs 3.3, 3.4 and 4.0.
- **Write for the next reader.** Comments say why, not what. Australian
  English.

## Telling hosts

A change a host can see isn't finished until it is written down (ADR 015):

- an entry in `CHANGELOG.md` under `[Unreleased]`, saying what changed for a host
  and why
- a step in `UPGRADING.md` if they have to do something, with the exact before
  and after
- the README, if the public API changed

## The pull request

Keep it to one thing. The commit message is the record of the reasoning: what was
wrong, what was believed that turned out false, what you chose and what you
turned down. Close the issue from it with `Closes #123`.

## Support

Janela is pre-1.0 and its public surface can still move between releases, with
an upgrade note each time. Issues and pull requests are read when the maintainers
can get to them. There is no support contract and no promised response time. For
a vulnerability, follow [SECURITY.md](SECURITY.md) and not a public issue.
