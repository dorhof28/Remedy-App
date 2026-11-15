# Phase 5: Cleanup, Simple look pass, commit

Order: 5.1, 5.2, 5.3, 5.4, then Dorron commits.

---

## 5.1 Clean the app
helper: scout, then coder

Brief for scout: list screens, settings and sample flows that nothing links to anymore, or that duplicate a newer one. One line each with file and why. Also list demo-only code paths (LaunchOptions flags and what uses them).
Lead shows the list to DORRON, who picks what goes. Then coder removes only the picked items and runs the tests.

Done when: Dorron's picks are removed and the build and tests pass.

---

## 5.2 Clean the code
helper: quick, then coder

Brief for quick: write `scripts/unused.sh`: for every `func`, `struct`, `class`, `enum` and `var` declared in `Remedy/`, count how many times its name appears in `Remedy/`, `RemedyTests/` and `RemedyWidget/`; print the ones that appear only once, as file:line name. Run it and give the list to the lead.
Brief for coder: from that list, remove what is truly unused (check `@objc`, previews, intents and SwiftData models before removing). Remove `Services/AI/Apple/ApplePlanReader.swift` and `Gemini/*` if Phase 1 replaced them. Merge duplicate helpers if any are obvious. Make every comment match the house style.

Done when: build and tests pass, and the unused list only has false positives.

---

## 5.3 Tidy the folder
helper: quick

Brief: add `DemoVideo/.build/`, `SamplePapers/print-check/` and `/tmp` style leftovers to `.gitignore`. List anything else in `git status` that is not app code (Backup-before-comments, WidgetDrafts, DemoVideo media) with its size, and ask DORRON what to move or ignore. Move nothing without his OK.

Done when: `git status` shows only real app files and the sample papers.

---

## 5.4 Simple look pass
helper: coder, with DORRON

Brief: lead lists every screen added in phases 0 to 4. For each, coder checks the Simple version: big buttons, one thing per screen, plain words, Read to me works, no logic in the view. Fix what doesn't fit. DORRON tries each one and says what still feels wrong.

Done when: Dorron has tried each new feature in the Simple look.

---

## 5.5 Commit
DORRON commits and pushes from his Mac. Claude never commits or pushes.
