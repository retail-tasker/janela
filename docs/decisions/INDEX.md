# ADR Index

Topic-tagged map of all ADRs. Read this **before any non-trivial task**
to find which decisions are already made.

Every ADR carries `Triggers:` and `Topics:` near the top. Grep for
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
| **Vision, scope, forkability** | 001, 010, 012 |
| **Open-source & host-decoupling** | 001 |
| **DSL & query layer** | 002, 006, 007 |
| **Dependencies** | 002, 003, 004, 006, 017 |
| **Authorisation** | 002, 003, 004, 009, 017, 019 |
| **Performance & storage** | 007, 017 |
| **Cross-filtering & Hotwire** | 003, 004, 005, 008 |
| **Layouts & views** | 011, 012, 016, 018 |
| **CSS & styling** | 016, 018 |
| **Frames, panes & persistence** | 012, 013, 014, 019 |
| **Naming rule** | 014 |
| **JavaScript delivery & charts** | 004, 006 |
| **Time dimensions** | 006 |
| **Routes, URLs & naming** | 005, 007, 008, 009, 011, 013 |
| **Snapshots & publishing** | 009 |
| **AI agents & guidance** | 010, 015 |
| **Releases & upgrades** | 015 |
| **Security** | 003 |
| **Testing** | 003 |

## Chronological

| ADR | Title | Date | Status |
|-----|-------|------|--------|
| 001 | Built to Be Forked | 2026-09-11 | Accepted |
| 002 | Measures and Dimensions over Ransack | 2026-09-13 | Accepted |
| 003 | Cross-filtering with Turbo Frames | 2026-09-13 | Accepted |
| 004 | Charts and JavaScript Delivery | 2026-09-15 | Accepted |
| 005 | Pane URLs and the Mount Path | 2026-09-15 | Accepted |
| 006 | Time Dimensions with Groupdate | 2026-09-15 | Accepted |
| 007 | Ordering and Limits | 2026-09-15 | Accepted |
| 008 | Dashboard Filters in the Page URL | 2026-09-15 | Accepted |
| 009 | Snapshots | 2026-09-15 | Accepted |
| 010 | Agent Guidance Ships, the Agent Waits | 2026-09-15 | Accepted |
| 011 | Panes Do Not Render in the Host Layout | 2026-09-15 | Accepted |
| 012 | Frames and Panes Are Data | 2026-09-15 | Accepted |
| 013 | Naming and Addressing Frames | 2026-09-15 | Accepted |
| 014 | Corrections Before Frames Are Built | 2026-09-15 | Accepted |
| 015 | How Breaking Change Is Communicated | 2026-09-16 | Accepted |
| 016 | The Styling Vocabulary | 2026-09-16 | Accepted |
| 017 | Janela Owns No Data Store | 2026-09-16 | Accepted |
| 018 | A Table Is the Universal Renderer | 2026-09-16 | Accepted |
| 019 | A Created Frame Asks the Host Who Owns It | 2026-09-16 | Accepted |

## Next number

Next ADR: 020
