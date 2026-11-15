# Remedy polish: handoff (2026-11-09)

Read this first, then the helpers' notes in this folder (onboarding.md, plan.md, style.md), if they wrote them.
Nothing is committed. Dorron must approve any commit.

## Dorron's latest asks (round 2)
1. Uniform, native polish across every screen. Not just plain text, more visual. Motto: "Your health, made simple".
2. Redesign the "how your papers are read" setup screens.
3. Make demo-mode import easier.
4. Restyle the restore-from-backup popup (and every screen) in the new look.
5. Before/after-surgery question: drop it if not needed. **DONE (see below)**
6. Free online APIs and how to set them up. **ANSWERED in chat**: Groq, Gemini, OpenRouter, Mistral, Ollama on the Mac, other OpenAI-compatible providers. All already supported in ModelChoice.
7. Model downloads look stuck. **FIXED (see below)**
8. Extra attention on the Plan tab.
9. Onboarding asks for Face ID/passcode lock, calendar and reminders.

## Helpers (background agents) and their file ownership
- Onboarding helper: Welcome/*, AIChoiceView, LocalModelList, SimpleReaderChoiceView, Demo/TestCases views, restore view, AppLock, CalendarService. Covers items 1-4 and 9 for those screens. Sim iPhone Air 4AD2FCCB.
- Plan helper: Plan/* in both looks, plan view models, Core PlanWording/PlanAgenda/PlanCalendar/RuleReminders. Sim iPhone 17e D339D9F4.
- Style helper: shared components (Theme, Cards, Components, SimpleComponents, ClassicUI/Components) and the Today, Medicines, Ask, Help, CheckIn, Photos, Emergency, Share and Settings screens. Sim iPhone 17 BC3A9F88.
- All were told to stop, leave their files compiling, and write handoff notes here.
- When resuming, read their notes, rebuild, then continue whatever is left in each area. Either restart helpers with the same ownership split, or do the rest directly.

## Done by me this round
- **Downloads** (Services/AI/Local/LocalModels.swift)
  - The new `FileFetcher` polls `countOfBytesReceived` every 0.3 s, since the old per-task delegate never reported progress.
  - Resume data plus 4 retries, and waitsForConnectivity.
  - The screen stays awake while downloading; progress never moves backwards.
  - Tested against Hugging Face: tokenizer.json downloaded at the full 6,838,609 bytes.
- **Paper kind**
  - The question is gone (`ScanFlowViewModel.chooseIntake` calls `chooseKind(.notSure)`, and `asksKind` is false for notSure).
  - PlanImporter sets each medicine, rule and task's paper from its own day (`PaperClues.kind(forDay:fallback:)`; day 0 or nil uses the page's guess).
  - `AIPrompt.prompt` uses a neutral "may cover both" line when `PaperClues.coversBoth` is true or the page has no clear clue.
  - Tests are in RemedyTests/PaperKindByDayTests.swift. **NOT RUN YET**: the build was broken by the Plan helper mid-edit.
- **Rule reminders** (earlier this session): Core/RuleReminders.swift, ViewModels/RuleReminderRows.swift and RuleRemindersTests. These pass.

## Next steps
1. `REMEDY_SIM=D0D218B4-6572-49FA-A063-EE1DA85F1EF6 REMEDY_DD=/tmp/dd-main scripts/check.sh build`. If it fails, fix the helper leftovers (last seen: SimplePlanView.swift:185 non-exhaustive switch, PlanView missing `moreRows`).
2. Run `scripts/check.sh test PaperKindByDayTests`, then the full `scripts/check.sh test`.
3. Run the new scans through the reader. RemedyTests/ZZReaderDump.swift currently holds a `ZZScanCheck` test.
   - It reads the scratchpad `scans/scanned.pdf` (1 page, a fictitious "After Visit Summary" with a numbered list, a bullet and a date tile) and `scans/long.pdf` (5 pages, image-only).
   - It writes `dump2/*.txt` with the text, notes and the rules-only hidden text.
   - Check the list formatting, the date tile, and that the name, MRN and DOB are hidden but the doctor is not.
   - Afterwards, empty the file again (rm is denied; Dorron deletes it).
4. Known reader issue: a tilted two-column-ish page (IMG_0173) still interleaves "Missing doses / container and show it" lines. The slope from observation corners seems ~0 even though boxes are tall. Idea: estimate the slope from box height vs width when the corners say flat.
5. Review the helpers' screenshots (scratchpad audit/onb, audit/plan, audit/style), then run a reviewer pass against CLAUDE.md.
6. Final summary for Dorron.

## Notes and caveats to tell Dorron
- Test GLM-OCR and Gemma downloads on an iPhone 17 Pro. The simulator can't run MLX.
- The increased-memory entitlement may need the capability on his team.
- He should confirm the new AIPrompt hour-rounding rule: 24h → -1, 36/48h → -2.
- PCC stays gated by `AppleAI.usesCloud`.
- The swift-transformers package was added.
- The EmergencyInfoTests phone check changed to "555-0142" (it's formatted now). The redaction second look runs only for model finders.
- The reviewer flagged that some Core files import SwiftData (Journey, DayChecklist, MedicineMatcher, PlanAgenda, DoseSchedule, ReminderPlan). These predate this session.

## Scratchpad (may vanish on reboot)
/private/tmp/claude-501/-Users-dorronhoffman-Developer-Remedy/78a67c7a-bcf0-4a9c-b441-225147f3be79/scratchpad
- photos/ and full/: Dorron's real HEIC photos (real patient info, NEVER copy into the repo). The originals are IMG_0168–0173.HEIC in ~/Downloads.
- scans/: the copies of ~/Desktop/Claude/Long.pdf and "Scanned Document.pdf".
- dump/ and dump2/: reader output. audit/: screenshots.

## Helpers were stopped mid-work at the usage limit
They may not have written their own notes. The build may be broken in Plan files (SimplePlanView switch, PlanView moreRows); fix that first.

## Resumed 2026-11-09 evening
- Build and full suite are green. Two PaperCluesTests now expect no before/after question (Dorron asked for that). ReaderSetupTests compile was fixed.
- The scans read well. Added: the EID/CEID labels are hidden, and a "number looks smudged" note appears for things like "1] 1/18/2026" (it's flagged, never auto-fixed).
- ZZReaderDump.swift was emptied again. A stray file RemedyTests/ZZReaderDump.swift.keep may exist; delete it.
- The three helpers were resumed with their own context to finish onboarding/setup, Plan, and the style pass.

## Later the same night
- Marcus, Lena and Frank were removed from the app (demo cards, the -demoPatient launch option, the DemoPatient enum). The demo mode "Start here" group is now surgeryIn10Days, surgeryTomorrow, threeDaysAfter and conflictingPapers. Use `-demoScenario <rawValue>` for screenshots. The paper sets were renamed kneePapers/gallbladderPapers/herniaPapers and SampleHealthRecord; tests use the same checks via RemedyTests/TestSamples.swift. Repo SamplePapers/ files keep their old names (tests only).
- Simple never scrolls: the new SimpleFit (SimpleUI/Components/SimpleFit.swift) steps text down to the default size, then shrinks to fit. SimpleScreen, Simple Home and every Simple FitOrScroll use it. Only these still scroll: keyboard forms (paper details, edit screens) and reading a full paper page on check-hidden.
- NumberRepair (Core) fixes clear misreads in dates and doses and adds a note for each fix.
- The Plan helper was still running at this point. It was told to use -demoScenario and the no-scroll rule.

## Final state of this round
- All helpers are finished. The Plan redesign, onboarding/setup/restore/demo work and the style pass are done. The full test suite passes.
- The next-up bar is now hidden on the Plan tab too. The prompt-example names were changed to Owen Tarrant / Dana Whitlow. FileFetcher's TaskBox now uses a lock.
- Open: Core/PlanAgenda.swift (pre-existing) imports SwiftData, as do DoseSchedule, ReminderPlan, DayChecklist, MedicineMatcher and Journey. Moving them to plain structs would be a separate refactor. PlanAgendaList and PlanTab are unused leftovers. Dark mode and the largest text sizes were not fully screenshot-audited. Simple sub-screens of the Plan tab were not shot with a busy plan.
- 2026-11-10: Core is now free of SwiftData. Core/PlanFacts.swift defines read-only protocols (MedicineFacts, RuleFacts and so on) and generic types (DoseSlotOf and others). Persistence/*+Models.swift makes the models conform and keeps the old names as aliases. A grep of Core for SwiftData, model names or PersistentIdentifier returns 0 lines. The full suite passes (504), with the new CorePurityTests.

## 2026-11-10 round (latest user list: crashes, UI polish, logo, wording, Mac connector, preview, dates, hospital)
- crashes: device logs showed (a) Metal validation SIGABRT in MLX GlmOcr -> GPU validation + frame capture off in Remedy, Remedy Demo, Remedy Demo Tour schemes; (b) watchdog kill from PaperCheckReport.of in view bodies -> fingerprint cache (PaperCheckInput.fingerprint) + MedicineIdentity.genericPhrases built once
- logo: BrandFooter now uses Image("Logo") (the real pill icon)
- new Core: InstructionTopics (topic per instruction, display only), DateRoles (paper date never a visit/surgery/birth; AI date rejected when labelled other), HospitalFinder (HSS etc from letterhead/logo text), MacModelPick
- Paper.hospitalName (optional) + DraftPlan.hospitalName + backup field; shown on paper details "From:"
- check-what-gets-sent now opens on formatted Text (tabs Text/Photo), word + hidden counts; PaperLayout drops ** and turns table pipes into dots
- Mac connector: Services/AI/Local/MacConnector (tries :1234 LM Studio then :11434 Ollama, /v1/models), MacConnectionViewModel, Components/MacConnectionPanel; yourMac renamed "Your Mac"; 600s timeout for Mac planning
- helpers (bg): Today+CheckIn+take animation (opus), Medicines (opus), Plan+topics+no "rules" (opus), Settings/demo/reader setup/Ask + embed MacConnectionPanel (sonnet)
- user's Mac: M3 Max 36GB, LM Studio has qwen/qwen3.6-35b-a3b (recommended), gemma-4-e4b
- oMLX added to Mac connector: port 8000, needs API key (Keychain, keyName yourMacAPIKey); 401/403 -> needsKey; user's oMLX is host 127.0.0.1 so must set 0.0.0.0
- all 4 helpers finished; full suite passes (sim D0D2, /tmp/dd-main)
- papers-disagree: rules fine, but old demo only made blue notes (surgery team covers apixaban, rule 5). demo now drops surgery team's apixaban and adds SamplePatients.b5 (heart, Nov 18, stop -5) vs b2 -> red card. ConflictDemoTests guards it + cache vs fresh check
- open: Today ring counts doses (0/1) while chip counts doses+tasks ("2 left"); classic red card has 4 stacked buttons, could be compact; RemedyUITests/MedicinesPolishShots.swift added by helper (keep or delete); check-in lost photo strip + simple text/email buttons (confirm with Dorron)
