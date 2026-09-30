# Security

## Reporting a vulnerability

Please report it privately, not in a public issue:

**https://github.com/retail-tasker/janela/security/advisories/new**

That opens a private advisory that only the maintainers can see. Tell us what
you found, the version of Janela and Rails you found it on, and the smallest
steps that show it. A failing test is the best report.

Janela is maintained by a small team without a support contract, so we can't
promise a reply time. We read every report, we will say so when we have, and we
will tell you what we decide. A fix ships as a patch release with a note in the
changelog, and we credit you there if you want that.

## What counts

Janela reads data on behalf of a person and shows it to them, so the things that
matter most are the ones that show someone data they should not see or run a
query they should not be able to run:

- a filter, a pane URL or a stored pane that reaches rows outside the host's
  `policy_scope`, or a model the host has not declared
- a filter that widens what can be read, or a request that makes the database do
  unbounded work (ADR 025)
- SQL or markup reaching a query or a page from text a reader or an analyst
  typed (ADR 039)
- a check in the doctor that says a host is safe when it is not (ADR 035)

Authentication and authorisation belong to the host application, and Janela
reads through them (ADR 032). A dashboard that is public because the host never
asked for a login is that host's setting, not a defect here, and `rails
janela:doctor` says so.

## Which versions

Janela is pre-1.0. Security fixes go into the latest release only. After 1.0,
the latest minor release of the current major version.
