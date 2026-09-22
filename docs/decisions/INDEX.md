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
| **Open-source & host-decoupling** | 001, 022, 036 |
| **DSL & query layer** | 002, 006, 007, 020, 025 |
| **Dependencies** | 002, 003, 004, 006, 017, 025 |
| **Authorisation** | 002, 003, 004, 009, 017, 019, 022, 032, 033, 034, 035 |
| **Performance & storage** | 007, 017, 025 |
| **Cross-filtering & Hotwire** | 003, 004, 005, 008, 024, 025 |
| **Layouts & views** | 011, 012, 016, 018, 020, 027 |
| **CSS & styling** | 016, 018, 023, 026, 027, 036 |
| **Frames, panes & persistence** | 012, 013, 014, 019, 029, 030, 033 |
| **Naming rule** | 014, 023, 036 |
| **JavaScript delivery & charts** | 004, 006, 026 |
| **Time dimensions** | 006, 025 |
| **Routes, URLs & naming** | 005, 007, 008, 009, 011, 013, 022, 024, 025 |
| **Snapshots & publishing** | 009, 020, 028, 033, 034 |
| **AI agents & guidance** | 010, 015, 021 |
| **The doctor & checks** | 021, 025, 032, 033, 035 |
| **Releases & upgrades** | 015, 021, 032, 034, 035, 036 |
| **Accessibility & keyboard** | 024 |
| **Security** | 003, 025, 028, 031, 032, 034, 035 |
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
| 020 | Formatting Belongs to the Measure | 2026-09-16 | Accepted |
| 021 | A Check Has a Name, and a Host Can Silence It | 2026-09-16 | Accepted |
| 022 | A Host's Route Helpers Work Inside the Engine | 2026-09-16 | Accepted |
| 023 | Vitral Is a Theme, Not the Stylesheet | 2026-09-16 | Accepted |
| 024 | Selecting More Than One Value | 2026-09-16 | Accepted |
| 025 | Janela Bounds What a Filter Can Ask For | 2026-09-17 | Accepted |
| 026 | A Renderer Is the Seam, and HTML Comes First | 2026-09-18 | Accepted |
| 027 | The Gallery Is a Host Page, Built from the Gem's Helpers | 2026-09-18 | Accepted |
| 028 | The Predicate List ADR 025 Named Was Not Quite Right | 2026-09-18 | Accepted |
| 029 | A Pane's Frame Is Identified by Who It Is, Not by What It Shows | 2026-09-18 | Accepted |
| 030 | A Pane's src Belongs to Turbo, So a Host Talks to the Frame | 2026-09-18 | Accepted |
| 031 | A Subclass Inherits the Dashboard Its Parent Declared | 2026-09-19 | Accepted |
| 032 | Janela Will Not Read a Model It Cannot Scope | 2026-09-20 | Accepted |
| 033 | A Snapshot Is Told Who Owns It | 2026-09-21 | Accepted |
| 034 | Janela Will Not Freeze a Scope the Host Has Not Named | 2026-09-21 | Accepted |
| 035 | A Check Does What Janela Does, or It Says What It Saw | 2026-09-22 | Accepted |
| 036 | Janela Publishes What a Theme May Target, and Vitral Is Only One | 2026-09-22 | Accepted |

## Next number

Next ADR: 037
