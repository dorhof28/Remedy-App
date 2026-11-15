# Remedy overhaul: handoff (started 2026-11-15)

Dorron's ask, in order, no stopping to ask. Commit only at the very end, and only with Dorron's OK.

1. Rule 6 in PaperCheck: **DONE**. `PaperCheck.rule` calls `NewerPaperRule.decide`, and the old rule 5 surgeryAuthority is gone.
2. Fix the real gaps: **DONE** (8, 29 to 41, marked in MISSING-SCREENS.md).
3. **DONE** Simplify the whole app back into the CLAUDE.md layout:
   - **Core**: pure rules.
   - **Models**: SwiftData.
   - **Persistence**: saving and adapters.
   - **Services**: outside systems.
   - **Interface/ViewModels**: shared by both looks.
   - **Screens/ClassicUI** and **Screens/SimpleUI**: views that only draw.
   - Also: delete dead code, merge duplicates, refactor badly factored code, fix speed, smoothness and stability, and reorganize files and folders.
4. **DONE** Delete all the old tests, extra targets (the test targets and the Demo Tour scheme; the widget is a product feature and stays) and extra settings.
5. **DONE** (76 tests in RemedyTests, all pass, 0 build warnings except the kept GenerationError check) Write a new test suite that tests everything, then fix every bug it finds until none are left.
6. **DONE** (Avery Quinn sample plan, 34 shots in docs/app-media/classic, simple, first-run; fixed the Ask NSAID suggestion bug, 77 tests) Put a realistic fake sample plan in the app (fake name, 555-01xx numbers, SAMPLE), then take one screenshot of every screen for app media. No scrolling.
7. **DONE** (docs/README.md, FEATURES.md, SPECS.md, TECHNICAL-OVERVIEW.md) Write several .md files: purpose, features, specs, and a full technical overview of how each feature is implemented.
8. **DONE** (about 630 one-line comments on every type and non-obvious function) Comment everything, with no filler: a comment goes in only if it explains something.

Notes:
- `rm` is denied, so move deleted files to `~/.Trash/remedy-overhaul/`.
- Build with `scripts/check.sh build`.
- The design screens are in `docs/Remedy-Redesign-for-Coder/`.

Next: ask Dorron to approve one commit of the whole overhaul. Nothing is committed yet.

Follow-up 2026-11-15: removed the simple menu; centered the pain numbers in both looks; classic done today and plan timeline now open as sheets; retook the shots (simple renumbered 01-10). Six simple pages lost their only link (visits, to-dos, what changed, first week, share), so Dorron needs to decide whether to relink or delete them.
Follow-up 2026-11-15 (2): Simple Papers links What changed, Simple Help links Share with family; removed whole journey, plan group, preview week, classic family share and dead parts; 77 tests pass. App is 345 files, 51,453 lines.

## 2026-11-15 refactor pass (no comments trimmed)
- today: dayItems and DayItem gone, dayProgress counts doses, stop-today, check-in and to-dos directly (widget only user). today view models 2175 to 1894 lines
- medicines: list and detail each one view model for both looks (MedicinesViewModel, MedicineDetailViewModel), old files in ~/.Trash/remedy-overhaul/medicines, aliases removed. -471 lines
- scan flow split into ScanFlowViewModel + extensions
- no extra cache: today builds in about 2 ms (SpeedTests), paper check already cached by fingerprint
- 78 of 78 tests pass, app 363 swift files 52002 lines. nothing committed
