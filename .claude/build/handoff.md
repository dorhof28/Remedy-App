# Handoff (written 2026-11-06, so a new session can pick up)

Read this, then progress.md and the phase file. Lead rules are in the session prompt (plan, helpers, progress lines, reviewer, short summaries).

## State
- Phase 0 done and reviewed. Phase 1 done except 1.5 (offline MLX downloads), which is blocked. Phase 2 started, 2.7 (bottle check) is SKIPPED on Dorron's say, do everything else in phase 2. Nothing is committed (Dorron commits himself; the commit command was denied to helpers: branch phase-0 suggested, skip DemoVideo and SamplePapers/pdfs).
- Full `scripts/check.sh test` passed at the end of phase 1.

## Dorron's preferences
- No unnecessary code, no dead code. Changing or replacing old code is fine if it is better. Short messages.
- Simple look = old dashboard style: big buttons, one thing per screen, plain words, for older people, simple but good looking. Every screen change in both looks.
- Keep going without him when he is away; stop only for what needs his hands (real phone, own keys, commit, Xcode packages).
- Helpers cannot delete files or add packages (permission denied). Dorron deletes by hand later: Remedy/Core/NameFinder.swift, RemedyTests/TempMeasure.swift, RemedyUITests/TmpLook.swift (then MedicalWords.medicineWords(in:) is unused).
- Dorron allowed one pbxproj edit (linking MLXVLM). Adding the Hugging Face packages by helper was denied by auto mode: Dorron must add them.

## Design decisions made in phase 1
- Two model choices in Services/AI/ModelChoice.swift (ModelSettings): textReaderChoice (part 1, saved but does nothing yet, skipped on purpose) and plannerChoice (part 2, any reader). One adapter file per provider plus a ModelChoice entry plus one factory switch in PlanReader.swift. Never fall back silently; "Try On this iPhone instead?" button after a failed read.
- Redaction: on-phone AI first (AIRedactor, PhonePersonalInfoFinder) plus rules as double check, union of finds. Check screen ALWAYS shown before reading (both looks). Short digit-only AI finds (<7 digits) are never hidden. AI finds apply to every page. Redaction off = warning only (needsRedactionWarning), never default, never silent.
- Onboarding: Which papers? then How are you adding this? (photo, PDF, MyChart, Health) then read then "About this paper" confirm (AI plus PaperClues rules propose source, doctor, printed date; must be confirmed; date optional, "No date on it"). MyChart/Health skip questions (hospitalRecord). Classic: one screen. Simple: three one-question screens.
- Paper model: every item has paperID; Paper has source (surgeryTeam, specialist, primaryCare, hospitalRecord, other), field (heart, kidney, blood, diabetes, lungs, other), doctorName, printedDate. CarePlan.isSample drives the Sample data banner.
- Sample data: SamplePapers/ (10 papers, expected/*.json, records/lena-record.json, make-pdfs.swift) and Resources/SamplePatients.swift (Marcus, Lena, Frank). Phase 2.1 tests must match expected/*.json.

## Open items for Dorron
1. Phase 1.5: add in Xcode: github.com/huggingface/swift-huggingface (from 0.9.0, product HuggingFace) and github.com/huggingface/swift-transformers (from 1.3.0, product Tokenizers) to the Remedy target, and link MLXHuggingFace and MLXLMCommon from mlx-swift-lm. Then say "resume phase 1" (coder builds LocalModelStore, ModelChoice offline entries, MLXAdapter, one case in PlanReader.reader(for:) (approved), settings rows in both looks, LocalModelStoreTests).
2. Allow local networking: Remedy target > Info > App Transport Security Settings > Allows Local Networking = YES.
3. Verify default model names from provider docs (gpt-5-mini, openrouter/free picks a random model, llama-4-scout, mistral-small-latest, llama3.2-vision).
4. Try by hand: scan flow in both looks, Claude with own key (sheet appears once), OpenAI/OpenRouter, run SamplePapers comparison with keys (command at top of SamplePapers/results.md). On this iPhone result: meds 21/31, stop days 16/18, doses 12/13, 16.3 s/paper.
5. Commit.
6. Ideas to approve are in ideas.md.

## Phase 2 progress (updated)
- 2.1 and 2.6 done. 2.2 onward in order (2.2, 2.3, then 2.4 + 2.5 parallel), then reviewer. 2.7 SKIPPED on Dorron's say.
- DORRON TO CONFIRM (medical readings the engine made in 2.1): (a) ask-by day = first day the two lines differ (so Lena = day -4), and empty (= ask now) when they differ from the start (Frank ibuprofen); (b) for two "take" lines a day only counts when both papers give it, so "continue X" vs "take X until day -3" is treated as agree; (c) a blank strength on one paper is not a different dose; (d) rule 4 treats two "other" sources as the same team; (e) "not mentioned" only fires for a newer after-surgery paper from the same team; (f) group lines are never in losingItems. 
- PaperCheckNote has no link to the plan, so deleting a plan leaves its notes (idea).
- 2.6 not run on phone: Dorron signs in to Epic sandbox (login in docs/testing-connectors.md), checks Health Records in Simulator. `intent=order` added to MedicationRequest search, unverified vs Epic docs.
- 2.2 edge: a line that loses in one finding and wins in another is skipped everywhere (check in review). Core->Persistence layering break in DoseSchedule/ReminderPlan being fixed.
- DORRON TO DECIDE (found in the 2.2 safety check): an older paper says "stop apixaban days -5 to -1" and a newer one says "-2 to -1": the older line is dropped whole, so the only stop reminder is day -2 (the newer paper wins, matches Marcus's ibuprofen expected result). Keeping the day -5 reminder would mean stopping 3 days earlier than the newer paper says (clot risk), so left as is. Confirm this is what you want.
- CIRCULAR PRECEDENCE: three papers can beat each other in a circle (mix of printed and added dates), then all lines were dropped (0 doses). Lead chose option (a): when every line for a medicine would be dropped on a day, keep all lines and make it an open red finding, so no reminder vanishes. Confirm or pick (b) one fixed newest-first order or (c) follow the surgery team's newest dated paper.
- QUEUED (Dorron's ask): "let the person decide" step. Where the app cannot resolve something cleanly (circular papers, undated papers, ambiguous Ask match, group vs specific lines, anything red), explain the problem in plain words and let the patient pick, saved like a PaperCheckNote. An on-device-only AI "Explain this" button may rephrase the quotes already on the card (never decides, never adds medical claims); decisions stay plain rules plus the patient's choice. Both looks. Run after 2.4, demo-patient and circle fix finish (they touch PaperCheckViewModel, ResolveSheet neighbors).
- CIRCLE CAVEAT: with keep-all, a 3-paper circle shows 3 different doses (e.g. metoprolol 50/25/12.5 mg) the same day = double-dose risk, and the red message still says the app follows one paper. The queued "let the person decide" step must handle this: for a circle, no dose reminders for the conflicting lines, a red "Choose which paper to follow" card on Today/home, the patient's pick saved (PaperCheckNote style) and then followed; the red text must not claim one paper is followed.
- DORRON TO CONFIRM (let-the-person-decide step): (1) while a circle is open, NO doses/reminders for those lines until the patient picks (risk: missed doses of e.g. metoprolol); (2) Ask asks "which one do you mean" whenever 2+ different medicines match, not only on similar rank; (3) undated papers: patient picks, meanwhile the default paper is followed; (4) resolved circle says "You chose", not "Your care team chose"; (5) the on-device Explain text is not checked by a rule, only labelled as AI written (idea: block numbers/drug names not in the quotes).
- Not seen in Simulator: circle card, undated card, resolve sheet, Explain text, Ask choice buttons, What changed screens, blue notes, Not on your papers section.
- REVIEWER NICE-TO-HAVE (phase 2, not acted on): rule 4 "sameTeam" treats two `.other` sources (or two primaryCare with nil field) as the same team so the newer silently wins (blue); matches phase-2.md literally but `.other` is a catch-all, consider sending it to the red path. Core still imports SwiftData in Journey, MedicineMatcher, ReminderPlan, DoseSchedule (older files). The PKCE test verifier change is the real RFC 7636 Appendix B value (not a weakened test).
- Delete by hand when back: RemedyTests/TempMeasure.swift, Remedy/Core/NameFinder.swift, RemedyUITests/TmpLook.swift.
- DORRON TO CONFIRM (phase 2 review fix): findings that are red from the start or open circles ("ask now", e.g. Frank's ibuprofen) now get a "Call <office> about <medicine> today." reminder at the next 9:00 AM (the old test said none; test updated on purpose). Also: a dated finding whose ask-by day has passed while still open gets NO further reminders; should it switch to "ask now" (daily nag)? Left as is.

## RUN PHASES 3 AND 4 IN PARALLEL WAVES (Dorron's ask: as much at once as possible)
Dorron still wants a short plan shown and one OK before starting, then go. Files were read: phase-3.md, phase-4.md, phase-5.md.

Rules for parallel helpers (all briefs must include them):
- Edit existing files with Edit only (never rewrite a whole shared file with Write), re-read the file right before editing, keep edits minimal. Shared hot files: TodayViewModel, SettingsViewModel + both Settings views, RemedySchema.models, MigrationTests, FamilySheetPDF, MedicineInstruction, CarePlan.
- If a build fails oddly from another helper's half-done edit, wait a minute and retry; never "fix" their files.
- At most 5 helpers at once (xcodebuild on one DerivedData contends). No helper edits project.pbxproj except the single build-setting keys named in a step. No deleting, no packages.
- Lead logs one progress line per finished step, copies Idea lines, runs `scripts/check.sh test` after each wave, one reviewer per phase at the end (phase 3 and phase 4 reviewers can run at the same time).

Dorron should do these BEFORE the run so nothing blocks:
1. Create the watch target now (4.5): Xcode > File > New > Target > watchOS > App, name "Remedy Watch", companion to Remedy.
2. Add the Hugging Face packages (see Open items) so step 1.5 can run in wave 1.
3. Confirm the Widget target exists and tell the lead (3.5 puts RemedyActivity.swift where both can see it).

WAVE 1 (5 at once, disjoint files): 3.4 engine (last-given, changes AI plan types, MedicineInstruction lastGivenAt, DoseSchedule), 3.3 printing + Everything page + before/after PDFs, 3.6 Calendar, 3.7 Preview first week, 4.3 Photo timeline (new model + schema line) and, if the packages are in, 1.5 as a 6th only after one of these finishes.
WAVE 2 (after 3.4 is done; 5 at once): helper A does 3.1 then 3.2 in sequence (3.2 needs 3.1's answers); 3.5 Live Activities (CarePlan arrivalTime/hospital, widget, DayChecklist, FastingTimes; one build setting key); 4.1 Recovery check-in (new CheckIn model + schema line); 4.2 Report a mistake; 4.4 Flexible goals.
WAVE 3 (after waves 1 and 2): 4.6 Face ID (one build setting key), 4.7 Emergency info (needs 3.3 done because both edit FamilySheetPDF), 4.8 Backup (engine; must come after 4.1 and 4.3 so CheckIn and PhotoTrack exist; HomeBottle does NOT exist because 2.7 was skipped, so leave it out of the snapshot list; include Paper, PaperCheckNote, CheckIn, PhotoTrack and every other model in RemedySchema.models), 4.5 Watch (target made by Dorron beforehand; touches TodayViewModel + new WatchBridge).
REVIEW: phase 3 reviewer and phase 4 reviewer in parallel, send MUST FIX to one coder batch each, then a full `scripts/check.sh test`.
PHASE 5 in parallel: 5.1 scout (unused screens/settings/demo paths) + 5.2 quick (write scripts/unused.sh and run it) + 5.3 quick (.gitignore + list of non-app files with sizes) at once; then show Dorron the 5.1 list and the 5.3 list and WAIT for his picks; then coder removes picked items (5.1) and cleans unused code (5.2, also remove ApplePlanReader.swift and Gemini/* only if truly unused; deleting needs Dorron: helpers cannot delete files, give him the list); 5.4 Simple look pass with Dorron; 5.5 Dorron commits.
Also pending from earlier: phase-1 step 1.5 (needs packages), the "-demoTab" idea, ideas.md items Dorron approved (none yet).

## DORRON AWAY 24h (written 2026-11-06 evening): decisions and reminders
- Decided: 2 = unclear AM/PM times use context, else patient picks AM/PM on the confirm screen. 4 = no (parser does not require 'last given'). 6 = newer paper wins plus What changed note (patient choice later). 7 = no reminders for circle lines until patient picks. 8 = daily 'call about X today' nudge when ask-by day passed. 9, 10 = yes. General rule: when unsure the app asks the patient.
- REMIND DORRON (non-obvious, he has not decided): (1) hospital day every-N-hours med: A one reminder at first home dose, or B continue every N hours from there within max per day (lead recommends B). (3) twice-daily meds: mark the slot at or before the hospital 'last given' time as done (lead recommends B). (5) warning signs picked by keywords (call/911/emergency/phone) plus fixed 'call if worried' line: ok? Do NOT build 1, 3, 5 until he answers.
- Dorron wants the app fully functional and tested in the real Simulator until he is back. QA findings go in .claude/build/qa-report.md. Phase 5 prep (5.1 scout list, 5.2 unused.sh, 5.3 gitignore + non-app list) runs meanwhile; nothing is removed until he picks. He will give a delete list to an agent himself at the end.
- 4.5 Watch and 1.5 offline models are parked on purpose.

## Dorron's answers (2026-11-07)
- 1 = Option A (every-N-hours: first home dose from last given, no extra doses; the paper's own hospital-day instructions apply). 3 = Option B (mark the slot at or before the hospital time done) plus ask "did you get that dose?" when unclear. 5 = yes (keyword warning signs plus fixed call-if-worried line). 4 = no. 8 = yes.
- 6 and 7 refined: precedence by purpose. The surgery team's pre-op/post-op papers are the authority for the surgery period; other doctors' papers that disagree are flagged (not followed, not dropped); circle/no-surgery-paper keeps patient-picks. Queued to the engine helper as step D, with C (twice-daily last-given).
- Permission note: a Bash call with simctl erase + rm was denied in this session even though Dorron said bypass is on. Dorron runs deletes/erase himself or re-enables bypass. Pending deletes: Remedy/Services/AI/Apple/ApplePlanReader.swift, Remedy/Services/Epic/SampleFHIR.swift. Simulator BC3A9F88-25B0-49F2-B6D2-C795E960F576 has a corrupt PosterBoard state (crashes in PRPosterDescriptor, no Remedy frames): erase it.
- Correction to D (Dorron 2026-11-07): conflicts are flagged ONLY when the surgery team did not consider the medicine (another paper lists a medicine the surgery papers never mention: calm 'not mentioned' note). If the surgery paper covers the medicine, it wins silently over other doctors and older papers (no flag). Two surgery papers: newest wins. Circle/no surgery paper: patient picks.

## NEW SESSION START HERE (written 2026-11-07)
Read this section, then progress.md (last lines), qa-report.md, ideas.md, cleanup-list.md, docs/phone-testing.md. No helpers are running. Full `scripts/check.sh test` passes (223 tests). Nothing is committed (Dorron commits).

### State
- Phases 0 to 4 built and reviewed, phase 5 prep done (5.1 list, 5.2 unused.sh, 5.3 gitignore, 5.4 Simulator QA + Simple pass). PARKED on purpose: 4.5 Apple Watch (needs watch target), 1.5 offline MLX models (needs Hugging Face packages), expanding beyond surgery (idea).
- Engine rules added after phase 4 (all tested): AM/PM question for unclear last-given times; daily 9 AM ask-by nudge; twice-daily hospital dose marks the slot done or asks 'did you get it'; surgery team papers win for the surgery period (pre-op papers up to surgery day, post-op from surgery day), a disagreeing line from another doctor is NOT flagged, only a medicine the surgery papers never mention gets a calm 'not mentioned' note; no card or note when the surgery paper wins, only the source line; Medicines list/search hide replaced lines; 'group line never beats a named medicine' kept red (Frank clopidogrel + aspirin); circle / no surgery paper keeps patient-picks; hospital dose within 6h before the first slot asks 'does this count as your 8 AM dose?'.
- Decided by Dorron: every-N-hours meds = first home dose from last given, no extra doses (option A); last-given parser does not need the words 'last given'; warning signs by keyword plus fixed 'call your surgeon if you are worried' line; calendar uses full access (own calendar only).

### Open questions for Dorron (ask first)
1. Marcus: heart doctor's 'continue aspirin 81 mg' is followed from day 1 after surgery, before any discharge paper restarts it. OK?
2. Frank ibuprofen now follows the surgery paper (OK until day -3) and his undated primary-care 'stop now' note is no longer shown. OK?
3. Frank clopidogrel/aspirin stay red. OK?
4. 'More settings' in Simple opens the Classic sheet: keep or build a Simple one?
5. Real papers: Dorron wants to try his own papers on the phone (on-phone reader first). Never put real papers in the repo or the sample folders.
Dorron said 'there is a lot to fix': ask him for his list first.

### Dorron's side
- His separate agent does all deletes (bypass permissions did not work for helpers). Delete list: Remedy/Services/AI/Apple/ApplePlanReader.swift, Remedy/Services/Epic/SampleFHIR.swift, RemedyUITests/SimpleLookPass.swift (empty), simulator 'Remedy Engine Tests' (made by a helper, optional). Unused-code cleanup (5.2 coder step, list in unused-list.txt: verdictSymbol, asNeededDetail, hasDischargeDate, signedDay, sortDate, uncheckedCount, medicineWords likely real) he does later.
- Not seen yet in Simulator: Live Activity (real device), last-given row (sample plan has no hospital time), adding a photo, backup restore past the file picker. Not run by hand: Epic sandbox sign-in, Health Records, own API keys, real phone install (free Personal Team may refuse HealthKit health-records / App Groups; fallback: phone build without them).
- Still open from before: Allow Local Networking set by Dorron (done). Commit is his.

### Known gaps and nice-to-have (not acted on)
Simple check-in has no note field and Simple photo screen no note field; PreviewWeek lacks one-day tasks; calendar does not re-sync for home date or edits outside Settings; Live Activity only refreshes when the app runs; saved items have no readBy (mistake reports say 'Not saved with the plan'); photo compare slider idea; timer for goals with seconds; goal fields not created by any screen; ready list / Everything page may not yet show everything; more ideas in ideas.md.

### Rules for the new lead
Helpers: scout (lookups), quick (tiny edits), coder (normal steps), engine (safety logic or failed steps), reviewer (once per phase). Parallel helpers: Edit only, re-read before editing, at most 5 at once, use a separate simulator for tests to avoid colliding. Always give the whole step text, log one progress line per step, copy Idea: lines to ideas.md, no commit/push, short messages. Dorron likes: no dead code, both looks for every screen change, Simple = big buttons and plain words, ask the patient when the app is unsure.
