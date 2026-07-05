# Flutter Coding Standards & Architecture Governance

**Purpose:** This is the single governing document for how this project is built, in code and in design. Save this file as `CLAUDE.md` at the repo root — Claude Code reads it automatically at the start of every session, so any AI-assisted coding stays consistent with these standards without you re-explaining them each time.

Aligned to Flutter's official architecture recommendations as of Flutter 3.44 (docs.flutter.dev/app-architecture, last verified May 2026).

---

## 1. Guiding Principles

Every architectural and code-level decision in this project is checked against these four, in this priority order when they conflict:

1. **KISS** — the simplest solution that correctly solves the problem wins. No abstraction is added speculatively.
2. **SOLID** — applied at the class/module level (below).
3. **DRY** — but only once duplication is proven, not anticipated. Premature DRY creates the wrong abstraction, which is worse than duplication.
4. **Clean Architecture** — dependencies point one direction only: UI → Domain → Data. Never the reverse.

### SOLID in Flutter/Dart terms
- **Single Responsibility:** a ViewModel manages one feature's state, a Repository owns one data type, a widget renders one concern. If a class needs "and" in its description, split it.
- **Open/Closed:** extend via composition (mixins, extension methods, strategy pattern for e.g. contrast-calculation variants) rather than modifying working classes.
- **Liskov Substitution:** any interface implementation (e.g. a `ColorExtractor` interface with k-means vs. median-cut implementations) must be swappable without breaking callers.
- **Interface Segregation:** small, focused abstract classes over one large one. A `ContrastCalculator` interface should not also expose CVD simulation methods.
- **Dependency Inversion:** ViewModels depend on Repository interfaces, never concrete implementations. Enables mocking in tests without a DI framework if the app stays small; introduce `riverpod` providers as the DI mechanism once it doesn't.

---

## 2. Architecture: MVVM + Feature-First

This is Flutter's own recommended pattern, not a personal preference — chosen so the project ages well against the framework's direction rather than against it.

**Two layers, strict dependency direction:**
- **UI layer:** Views (widgets) + ViewModels
- **Data layer:** Repositories + Services

**Component rules:**
| Component | Responsibility | Depends on |
|---|---|---|
| View | Renders UI state, forwards user events to ViewModel. Zero business logic. | ViewModel only |
| ViewModel | Converts repository data into UI state, exposes commands | Repositories (interfaces) |
| Repository | Single source of truth for one data type; caching, error handling | Services |
| Service | Wraps one external or platform integration (camera, file storage); stateless | Nothing above it |

**Folder structure — Feature-First, not type-first:**
```
lib/
  features/
    contrast_check/
      view/
        contrast_check_screen.dart
      view_model/
        contrast_check_view_model.dart
      widgets/
        contrast_badge.dart
    cvd_simulation/
      ...
  data/
    repositories/
    services/
  core/
    theme/          <- generated from design tokens, see §4
    routing/
    di/
```

Never organize top-level by type (`lib/widgets/`, `lib/models/`, `lib/screens/`) — that scales badly past a handful of screens and is explicitly what Feature-First replaces.

### Concurrency: Compute-Heavy Work Runs Off the Main Isolate

K-means color extraction and per-frame pixel sampling from the camera feed are CPU-bound and will jank the UI thread if run inline. This is a hard rule, not a later optimization pass:

- Any function operating on raw camera frame bytes or running k-means iterations executes inside a Dart `Isolate` (via `compute()` for simple cases, or a long-lived isolate + `SendPort`/`ReceivePort` if frames need continuous streaming rather than one-shot calls).
- Services in the data layer are the only place this belongs — a ViewModel should await a `Future` from the Service and never know or care that an isolate was involved underneath.
- Golden/widget tests should include a case that verifies the UI stays responsive (or at minimum doesn't block) during extraction — this is also a genuinely interesting benchmark to cite in the article on the k-means implementation.

---

## 3. Monorepo Structure (Melos 8 + Dart pub workspaces)

Matches your existing Melos experience — the app always consumes the package the way any external user would, which keeps the package's public API honest.

```
pubspec.yaml            <- workspace root: `workspace:` member list + `melos:` config key
pubspec.lock            <- single shared lockfile for the whole monorepo (committed)
packages/
  wcag_vision/          <- published package: contrast engine, CVD sim, k-means
apps/
  a11y_scanner/         <- the consumer app
tokens/
  tokens.json           <- W3C Design Tokens source of truth, see §4
```

**There is no standalone `melos.yaml`.** This document originally showed one — that reflected Melos ≤6, written before this repo had real code. As of Melos 8 running on Dart pub workspaces (Dart 3.12 / Flutter 3.44):

- The root `pubspec.yaml` declares members in a `workspace:` block, and each member package sets `resolution: workspace` — pub resolves everything against one shared root lockfile (no per-package `pubspec.lock`).
- Melos derives its package set from that same `workspace:` block and reads its scripts/config from the `melos:` key **inside the root pubspec**. A standalone `melos.yaml` is the legacy non-workspace layout, and in workspace mode its scripts are silently ignored — which is exactly how the error surfaced (`melos run` reported "no scripts defined" until config moved into the pubspec).

Corrected 2026-07-05 per §13 (update the doc when reality disagrees, don't silently deviate). New member packages/apps must be added to the `workspace:` list in the root pubspec.

---

## 4. Design Token Architecture (tool-agnostic by design)

Goal: one source of truth that Figma, Flutter, and any future tool can all read — nothing hand-copied between design and code, so they can't silently drift.

**Format:** [W3C Design Tokens Community Group format](https://www.w3.org/community/design-tokens/) (`tokens.json`) — this is the emerging cross-tool standard, not a proprietary format tied to one vendor.

**Why this format specifically:**
- Figma: the Tokens Studio plugin reads/writes this exact format, so your Figma file and codebase reference the same file.
- Code generation: Style Dictionary (or a lightweight custom build_runner script) transforms `tokens.json` into a Dart `ThemeExtension` — colors, spacing, typography scale all generated, never hand-typed into widgets.
- Future-proof: if you adopt a new tool in a year, it very likely also speaks this format, since it's the direction the whole design-tooling ecosystem is converging on — not just a Figma-specific export.

**Pipeline:**
```
tokens.json (source of truth)
   ├─→ Figma (via Tokens Studio plugin)
   └─→ build_runner → lib/core/theme/app_tokens.dart (generated ThemeExtension)
```

**Rule:** no hardcoded hex values, spacing numbers, or font sizes anywhere in `lib/`. Every value traces back to `tokens.json`. This is also what makes your contrast-checker's own UI a live demonstration of the accessibility principles it enforces — a detail worth calling out explicitly in the article/talk.

---

## 5. Enterprise-Grade Baseline, Regardless of App Size

This project is architected as if it will scale to enterprise complexity, even though v1 is a small, focused utility app. This is a deliberate choice, not over-engineering, for two reasons: retrofitting proper architecture onto a "simple app" later is far more expensive than building it correctly from day one, and a portfolio piece with enterprise-grade discipline is stronger GTV evidence than a quick utility script, regardless of how few screens it has.

**In practice, this means the small app still gets:**
- Full MVVM + Feature-First structure (§2) even for a 3-screen app — no shortcuts that would need undoing later.
- A Melos monorepo (§3) from the start, even though there's currently only one package and one app — adding a second package later (e.g. a design-system package, a reporting package) becomes trivial rather than a migration.
- Full DI via Riverpod providers (§7) from the first feature, not introduced "once it gets complex."
- CI/CD (§11) running on day one, not added once there's "enough code to justify it."

**What stays genuinely simple:** the *feature scope* of v1 (camera → contrast → CVD toggle → export), not the *architecture underneath it*. Scope and architecture are independent decisions — keep the former minimal (KISS), keep the latter production-grade.

---

## 6. Package Selection Policy

Prefer popular, well-maintained packages over hand-rolled boilerplate wherever one exists — but "popular" alone isn't sufficient. A package only qualifies as **safe to use** if it clears all of the following:

- **Active maintenance:** commits or releases within the last 6 months; an open, responsive issue tracker. A high download count on an abandoned package is a trap, not a signal — Flutter's own ecosystem has been burned by this twice already (see storage note below).
- **Pub.dev signals:** high Popularity and Pub Points, ideally carrying the "Flutter Favorite" tag where one exists for the category.
- **License compatibility:** MIT, BSD, or Apache 2.0. Avoid copyleft (GPL) licenses for anything shipped in the published package or app.
- **No unnecessary data collection or permissions:** consistent with this project's fully-offline, algorithmic-only design — a package that phones home or requests permissions beyond its stated purpose is disqualified regardless of popularity.
- **Reasonable dependency footprint:** avoid packages that drag in a large, unrelated transitive dependency tree for a small feature.
- **No open, unpatched security advisories** on pub.dev or the GitHub Security tab.

**Recommended packages by concern (checked current as of mid-2026):**

| Concern | Package | Note |
|---|---|---|
| Camera | `camera` (official) | Flutter Favorite, actively maintained by the Flutter team |
| Pixel/image manipulation | `image` | Pure Dart, widely adopted, active maintenance |
| State management / DI | `riverpod` + `riverpod_generator` | See §7 |
| **Local storage** | **`drift`** | **Not Hive or Isar** — both were abandoned by their original author; community forks exist but carry ongoing maintenance risk. Drift is SQLite-based, type-safe, reactive, and is the current community default for new projects. Use plain `shared_preferences` instead if all you need is simple key-value settings storage. |
| PDF export (compliance reports) | `pdf` + `printing` | Well-maintained, no native platform code required |
| Testing/mocking | `mocktail` | No code generation required, actively maintained, works cleanly with Riverpod's `AsyncNotifier` pattern |
| Linting | `very_good_analysis` | See §8 |

**Process for adding any package not on this list:** check the four criteria above against pub.dev and the GitHub repo before adding to `pubspec.yaml`, note the check in the PR description. This becomes a two-minute habit, not a formal review process — but it's a habit worth having explicitly, given how visibly the Flutter ecosystem has burned early adopters of popular-but-unmaintained packages in exactly this category.

---

## 7. State Management: Riverpod (with code generation)

Riverpod is the current de facto successor to Provider in the official ecosystem, and `riverpod_generator` removes the boilerplate that used to be the main objection to it. Given your Bloc-heavy professional background, this is a deliberate choice to diversify your public evidence — showing range across state management approaches strengthens a portfolio more than repeating what you already do at Cynergy.

- One `@riverpod` provider per Repository.
- ViewModels are `AsyncNotifier`s exposing immutable UI state classes (not raw booleans/strings scattered across the widget).
- No `setState` outside of pure, local, non-business-logic animation state.

---

## 8. Linting & Static Analysis

- `very_good_analysis` as the base lint set (stricter than `flutter_lints`, widely adopted in production Flutter teams) — layer project-specific rules on top via `analysis_options.yaml`.
- `custom_lint` + a project-local lint rule enforcing "no hardcoded token values" (§4) — this is exactly the kind of golden-test-adjacent CI enforcement you already do at Cynergy, reused here.
- Zero warnings tolerated in CI — the pipeline fails the build, not just the PR comment.

---

## 9. Testing Strategy

Pyramid, weighted toward the base:

1. **Unit tests** — contrast math, CVD matrices, k-means convergence. These are pure functions with deterministic outputs — aim for close to 100% coverage here, and cite the coverage number in the article as evidence of rigor.
2. **Golden tests** — every UI state (pass/fail badges, CVD toggle states, empty/loading/error) across at least two screen sizes. Your existing golden-test CI experience transfers directly.
3. **Integration tests** — camera → extraction → contrast report, end to end, on a real or emulated device.

CI runs all three via GitHub Actions + Melos scripts on every PR; golden test diffs post as PR comments.

---

## 10. Naming & Style Conventions

- `UpperCamelCase` — classes, enums, typedefs, widgets
- `lowerCamelCase` — variables, functions, parameters
- `snake_case` — file and folder names
- `UPPER_SNAKE_CASE` — compile-time constants only
- Every public class and method in `wcag_vision` carries a dartdoc comment — this package is a portfolio artifact, so its documentation quality is itself evidence.

---

## 11. Git & CI

- Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`) — enables auto-changelog generation for the package, which is another small but real piece of professional-grade evidence.
- GitHub Actions: analyze → test → golden test → (on tag) publish to pub.dev.
- Melos scripts (`melos run test`, `melos run analyze`) as the single entrypoint, matching your existing workflow.
- Never include a Co-Authored-By trailer, "Generated with Claude Code" footer, or any AI-attribution line in commit messages or PR descriptions. Commits are authored solely as the repo owner. (Belt-and-suspenders alongside the `attribution` settings in `.claude/settings.local.json` — the settings key alone is sometimes inconsistently honored.)

---

## 12. Accessibility Requirements (baked into standards, not bolted on)

- Every interactive widget has a `Semantics` label — enforced via a custom lint rule, not just code review memory.
- Golden tests include at least one pass at 200% text scale to catch layout breakage under accessibility settings.
- The app itself must pass its own contrast checker on its own UI — dogfooding as both a QA step and a talking point.

---

## 13. How This Document Gets Used

- Save as `CLAUDE.md` at repo root for Claude Code sessions to auto-load.
- Reference explicitly at the start of any Claude Sonnet/Fable chat session doing code review or architecture decisions on this project, if not using Claude Code directly.
- Treat as a living document — if a decision here stops making sense once real code exists, update it and note why, rather than silently deviating. That decision log is itself useful material for the article on engineering process.

---

## 14. Claude Code Skills Setup

Skills are reusable instruction packs Claude Code loads automatically when a task matches, supplementing (not replacing) this document. Installed once per machine/project, low ongoing cost since they load lazily.

**Install (via the official Dart-team-adjacent `skills` package on pub.dev — not a third-party npx wrapper):**
```bash
dart pub global activate skills
cd <project root>
skills get
```
This pulls from the `flutter/skills` and `serverpod/skills-registry` GitHub registries, auto-detects Claude Code, and installs into `.claude/skills/`. Commit `.claude/skills/` to git so it travels with the repo.

**Curated subset most relevant to this project** (the full registry installs regardless, but these are the ones expected to fire often):

| Skill | Reinforces | Why |
|---|---|---|
| `flutter-apply-architecture-best-practices` | §2 | MVVM + Feature-First |
| `flutter-managing-state` | §7 | Riverpod patterns |
| `flutter-add-widget-test`, `flutter-add-integration-test` | §9 | Testing pyramid |
| `flutter-improving-accessibility`, `flutter-accessibility-audit` | §12 | Core to the app's entire premise |
| `flutter-theming-apps` | §4 | ThemeExtension generation from tokens |
| `flutter-handling-concurrency` | §2 (Concurrency) | Isolate-based image/k-means processing |
| `flutter-caching-data`, `flutter-working-with-databases` | §6 | Drift usage patterns |
| `flutter-reducing-app-size` | — | Pre-submission App Store optimization |

**Two adjacent resources, noted but not adopted wholesale:**
- `Harishwarrior/flutter-claude-skills` (GitHub, manual `git clone` into `.claude/skills/`) — a testing skill plus an OWASP Mobile Top 10 security-audit skill. Outside the vetted registry, so apply the same check as §6 (last commit date, stars, read the actual `SKILL.md`) before pulling in.
- `vp-k/flutter-craft` — a heavier opinionated workflow plugin (brainstorm → plan → execute → verify → finish, via subagents/hooks) that already defaults to Riverpod + Clean Architecture + feature-first structure. Largely redundant with this document as written; worth knowing about if the automated `/plan` and `/execute` slash commands become appealing later, not needed now.
