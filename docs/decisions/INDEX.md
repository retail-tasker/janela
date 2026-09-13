# ADR Index

Topic-tagged map of all ADRs. Read this **before any non-trivial task**
to find which decisions are already made.

Every ADR carries `Triggers:` and `Topics:` near the top -- grep for
them when in doubt: `grep -l "Triggers:.*fork" docs/decisions/*.md`.

## How to use

1. Identify the area of the task (scope, DSL, cross-filtering, etc).
2. Look up the topic below to see which ADRs are relevant.
3. Read the relevant ADRs **before** writing code, advising, or making
   a decision in that area.
4. If the task spans topics, read all relevant ADRs.
5. If no ADR covers the area but the decision is significant, draft a
   new one.

## Topics

| Topic | ADRs |
|-------|------|
| **Vision, scope, forkability** | 001 |
| **Open-source & host-decoupling** | 001 |
| **DSL & query layer** | 002 |
| **Dependencies** | 002 |
| **Authorisation** | 002 |

## Chronological

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| 001 | Built to Be Forked | 2026-09-11 | Accepted |
| 002 | Measures and Dimensions over Ransack | 2026-09-13 | Accepted |

## Next number

Next ADR: 003
