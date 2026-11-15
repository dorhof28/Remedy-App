# Phase 2: Medicine checks

Goal: when papers from different doctors disagree, the patient sees it, with both quotes, and the app follows Dorron's precedence rules. Plus "What changed", record gaps, working MyChart and Health imports, and the bottle check.

Order: 2.1, then 2.2, then 2.3, then 2.4 and 2.5 (parallel ok), then 2.6, then 2.7.

---

## 2.1 The paper check engine
helper: engine

Files: new `Core/MedicineIdentity.swift`, new `Core/PaperCheck.swift`, new `Core/WhatChanged.swift`, new `Models/PaperCheckNote.swift` (+ add to RemedySchema), new `Persistence/PaperCheckInput.swift`, new `RemedyTests/PaperCheckTests.swift`. Read `Models/Paper.swift`, `Models/MedicineInstruction.swift`, `Core/DayMath.swift`, `Core/MedicineMatcher.swift` for conventions.

Brief:

Input: plain `CheckItem` structs built by `PaperCheckInput` from the plan's medicines and papers: paperID, paper source, field, isSurgeryTeam, printedDate (optional), addedAt, names (name + alsoKnownAs + brands from MedicineIdentity), isGroup, group members, isGeneric, action, startDay, endDay, strength, amount, quote.

Matching (`MedicineIdentity`):
- Exact normalized names only (lowercase, no punctuation, strength removed). No fuzzy matching.
- A small built-in brand table for the sample medicines: aspirin; clopidogrel/Plavix; apixaban/Eliquis; warfarin/Coumadin; ibuprofen/Advil/Motrin; naproxen/Aleve; metformin; metoprolol; lisinopril; atorvastatin/Lipitor; omeprazole/Prilosec; acetaminophen/Tylenol; oxycodone; fish oil/omega-3.
- Groups: NSAIDs = ibuprofen, naproxen, celecoxib, diclofenac, meloxicam (aspirin is not in it, pre-op papers name it on its own). Blood thinners = aspirin, clopidogrel, warfarin, apixaban, rivaroxaban. Vitamins and supplements = fish oil, multivitamin, vitamin E. A group line only applies to medicines the patient actually has (named on some paper or the record).
- Generic: a group line, or a line that names 3 or more medicines in one sentence (a standard list). Specific: a line about one named medicine.
- Same medicine with a different strength or amount on overlapping days is a "different dose" disagreement, not two medicines.

Compare only items from different papers (two lines on the same paper are one doctor's plan) whose day ranges overlap. Kinds: `differentAction` (take vs stop), `differentStopDay`, `differentDose`, `agree`.

Precedence, in this order (one constant `muchLaterDays = 30`, Dorron may change it):
1. Record items (source hospitalRecord) never win and never conflict. They only produce gaps (see below).
2. If either paper has no printed date: red.
3. Generic never beats specific: if the newer line is generic and the older is specific, red, even when rules 4 and 5 would give blue.
4. Same source and same field (or both surgery team): newer wins, blue "updated".
5. Surgery team newer than a specialist or primary doctor: surgery team wins, blue "updated by your surgery team".
6. Different fields in any other order (two specialists, specialist or primary doctor newer than the surgery team): red, unless the newer paper is more than `muchLaterDays` newer, then newer wins, blue.
Newer means printed date, then addedAt.

Results:
- `Finding`: medicine, kind, color (red, blue, green for agree), the two items with quotes and doctor names, winner paperID (blue) or default paperID (red), askBy day (red only) = the day before the first overlapping day they disagree, and which rule fired (for the patient-facing explanation and tests).
- Default while red: the surgery team's item if one is involved, else the newer one. Reminders follow the default until resolved.
- `PaperCheckNote` model: findingKey (stable: medicine + both paperIDs), chosen paperID, what the office said (text), who said it, date. A note turns a red finding into resolved with the chosen winner.
- Gaps: a record medicine no paper names gives a "not on your papers, ask your care team" gap.
- `losingItems`: item ids that are replaced (blue losers, resolved red losers). Phase 2.2 uses this to stop reminders for them.

What changed (`WhatChanged`): given the plan before and after a new paper is added, list new, changed (dose, stop day), restarted, still stopped, and not mentioned (on the old plan, missing from a new paper of the same kind that clearly replaces it, like a discharge paper).

Tests: one test per precedence rule, plus the 3 sample patients from `SamplePapers/expected/*.json` (load with a path from `#filePath`). Every expected result there must match, including ask-by dates.

Done when: all PaperCheckTests pass.

---

## 2.2 Ask, verdicts and reminders use the check
helper: coder

Files: `Core/AskAnswers.swift` (around line 46, the `.first` of the matcher), `Core/MedicineMatcher.swift`, `Core/ReminderPlan.swift`, `Core/DoseSchedule.swift`, `Interface/ViewModels/MedicineDetailViewModel.swift`, `TodayViewModel.swift`, `AskViewModel.swift`, `Services/Reminders/NotificationService.swift`, new `RemedyTests/AskCheckTests.swift`.

Brief:
- Run PaperCheck once per plan change through `PaperCheckInput` and share the result (a small cache in Persistence, not in a view).
- Ask: today the first ranked match wins silently. Instead, when the matched medicine has a finding: blue says "Your newer paper from <doctor> changed this" and shows both quotes; red says "Your papers disagree" with both quotes, what the app follows until the patient hears back, and the ask-by date.
- Medicine detail and Today verdicts say the same in one line.
- Reminders and dose schedule skip `losingItems`. While red, they follow the default item.

Done when: AskAnswers tests show "Can I take aspirin?" for patient C mentions both papers, and no reminder is scheduled for a replaced item.

---

## 2.3 Cards and the "What did the office say?" sheet
helper: coder

Files: new `Interface/ViewModels/PaperCheckViewModel.swift`, new `Interface/Components/PaperCheckCard.swift`, new `Interface/Components/ResolveSheet.swift`; Today (`TodayView`, `TodayBeforeView`, `TodayAfterView`, `ClassicUI/Components/TodayCards.swift`), `MedicineDetailView`, `PlanView`; Simple: `SimpleHomeView`, `SimpleMedicineDetailView`, `SimplePlanView`, `SimpleComponents.swift`; `NotificationService.swift`.

Brief:
- Red card: "Your papers disagree about <medicine>", both quotes with doctor and date, "Until you hear back, Remedy follows <doctor>'s paper", "Ask by <date>", a Call button (the paper doctor's contact if known, else the surgery team contact).
- Blue note: "Updated by your newer paper from <doctor>", both quotes, smaller.
- Resolve sheet: "What did the office say?" pick which paper is right, optional note and who said it, saves a PaperCheckNote.
- One notification on the ask-by morning: "Call <doctor>'s office about <medicine> today."
- Simple look: one big card per red finding on the home screen, plain words, Call and "They told me" buttons. Blue notes only on the medicine screen.

Done when: patient C in demo mode shows the red cards in both looks.

---

## 2.4 What changed
helper: coder (parallel ok)

Files: new `Interface/Screens/ClassicUI/Views/Plan/WhatChangedView.swift`, new `Interface/Screens/SimpleUI/Views/Plan/SimpleWhatChangedView.swift`, `PaperCheckViewModel.swift`, `ScanFlowViewModel.swift` (show after saving a new paper).

Brief: after a new paper is saved into an existing plan, show What changed: New, Changed, Restarted, Still stopped, Not mentioned (with "Ask your care team"). Also reachable from Plan. Simple: one section per screen with big Next.

Done when: patient B's discharge paper shows the expected list.

---

## 2.5 Record gaps on the Medicines screen
helper: quick (parallel ok)

Files: `MedicinesViewModel.swift`, `MedicinesView.swift`, `SimpleMedicinesView.swift`.

Brief: show PaperCheck gaps in a "Not on your papers" section: name and "Ask your care team if you should keep taking this." Data comes from the shared check result.

Done when: patient B with the record shows omeprazole there.

---

## 2.6 MyChart and Health imports fully working, with a test path
helper: coder

Files: `Services/Epic/*`, `Services/Health/*`, `Interface/ViewModels/ConnectionCheckViewModel.swift`, `ConnectionCheckView.swift`, new `docs/testing-connectors.md`.

Brief:
- Walk the MyChart sign-in and import against Epic's public sandbox (fhir.epic.com test patients) and fix what breaks. Read EpicConfig for the client id and redirect; if a client id must be registered, stop and give Dorron the exact steps.
- Health Records: check the HealthKit clinical records import against the Simulator's sample records, and fix what breaks.
- Add "Test with a sample patient" in Connection check that runs `records/lena-record.json` through the same importer with no network.
- `docs/testing-connectors.md`: short numbered steps anyone can follow for both.

Done when: the sample patient button imports 4 medicines as a hospitalRecord paper. DORRON tests the sandbox sign-in on a real phone.

---

## 2.7 Bottle check
helper: coder

Files: new `Interface/Components/BottleScanner.swift` (VisionKit `DataScannerViewController` live text), new `Core/BottleMatch.swift`, new `Models/HomeBottle.swift` (+ RemedySchema), new `Interface/ViewModels/BottleCheckViewModel.swift`, new Classic and Simple views in `Medicines/`, `PaperCheckInput.swift`, new `RemedyTests/BottleMatchTests.swift`.

Brief:
- Point the camera at a pill bottle. BottleMatch reads the label text and matches with MedicineIdentity only (exact names and brands, strength parsed). If unsure, show the top 2 and let the patient pick. Never guess.
- Verdict from today's plan in one big line, like "Your plan says: don't take this until Dec 15" or "Not on your papers. Ask your care team."
- Save the bottle as HomeBottle (names, strength, date scanned). Saved bottles feed PaperCheck gaps like record medicines.
- Camera usage text already exists for the scanner, reuse it.

Done when: BottleMatchTests pass on label strings like "ELIQUIS 5MG TAB" and "Apixaban 5 mg", and a printed fake label gives the right verdict (DORRON by hand).
