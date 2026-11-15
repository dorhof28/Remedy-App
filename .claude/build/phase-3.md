# Phase 3: Surgery days

Goal: help on the days that matter most: stop days, the day before, surgery morning, and the first dose at home.

Order: 3.4 first (it changes the AI plan types), then 3.1, 3.2, 3.3, 3.5, 3.6, 3.7. Steps 3.3, 3.6 and 3.7 touch different files and are parallel ok.

---

## 3.4 First home dose from "last given"
helper: engine

Files: `Services/AI/AIPlan.swift` (+ `lastGivenText`), `Services/AI/AIPrompt.swift`, `Services/AI/PromptExamples.swift`, `Services/AI/AIPlanConverter.swift`, `Services/AI/Gemini/GeminiSchema.swift` and the cloud schema from 1.6 if separate, new `Core/LastGivenParser.swift`, `Core/DoseSchedule.swift`, `Models/MedicineInstruction.swift` (+ `lastGivenAt: Date?`), `Persistence/DraftPlan.swift`, `PlanImporter.swift`, new `RemedyTests/LastGivenTests.swift`.

Brief:
- The AI copies the "Last given" line for a medicine word for word into `lastGivenText`. It never computes a time.
- `LastGivenParser` is strict: it returns a time only if `lastGivenText` contains a clock time (1:40 PM, 13:40, 1:40pm) AND that exact text appears in the page text. Otherwise nil. The date is the paper's printed date (discharge day).
- DoseSchedule: when `lastGivenAt` exists, the first home dose and "next one OK at" start from it, using minHoursBetween or the every-N-hours rule. Respect maxPerDay counting the hospital dose for that day.
- The patient sees "Last given in the hospital at 1:40 PM (from your paper)" so they can check it.
- Tests: patient B discharge paper gives next oxycodone OK at 5:40 PM and acetaminophen at 5:00 PM; a made-up time not on the page gives nil; "last given: this morning" gives nil.

Done when: LastGivenTests and the existing tests pass.

---

## 3.1 Optional last-dose question
helper: coder

Files: `Interface/ViewModels/TodayViewModel.swift`, `ClassicUI/Components/TodayCards.swift`, `SimpleHomeView.swift` (stop card), `Persistence/MedicineActions.swift`, `Models/MedicineInstruction.swift` (+ `lastTakenAnswer: String?`, `lastTakenAt: Date?`), `SettingsViewModel.swift`, `SettingsView.swift`, `SimpleSettingsView.swift`.

Brief: off by default (Settings switch "Ask me on stop days"). When on, a stop-day card asks "Did you take any <medicine> today?" Yes / No. Yes shows: "Your paper says not to. You may want to tell your surgeon's office." with a Call button. It's a soft question, never blocking. Save the answer.

Done when: off, nothing changes; on, the question shows on a stop day in the sample plan.

---

## 3.2 Ready for surgery list
helper: coder

Files: new `ClassicUI/Views/Today/ReadyForSurgeryView.swift`, new `SimpleUI/Views/Home/SimpleReadyView.swift`, `TodayViewModel.swift` (a ready section).

Brief: shown on day -1. Every stop in the plan with its status from what the patient said: stopped on time, took late (from 3.1), or no answer. Plus fasting and arrival time if known. Only uses what the patient recorded, never assumes. Simple: one item per line, big checkmarks.

Done when: shows on day -1 in the sample plan in both looks.

---

## 3.3 Better printing and the Everything page
helper: coder (parallel ok)

Files: `Services/Sharing/FamilySheetPDF.swift`, `Interface/Components/FamilySheetPage.swift`, `FamilyShareViewModel.swift`, `FamilyShareView.swift`, `SimpleFamilyShareView.swift`.

Brief: clearer layout and bigger type for all printed pages, a cover summary (procedure, surgery date, who to call), and a new "Everything" page: medicines with stops and restarts, visits, rules, contacts, the ready list, and any open red paper-check cards. Keep the existing Day, Medicines and Journey pages. Before changing anything, add a small test that renders the sample plan's PDF to `SamplePapers/print-check/before.pdf` (path from `#filePath`). After the redesign it writes `after.pdf`, so Dorron can compare.

Done when: both PDFs exist and the share sheet still works in both looks.

---

## 3.5 Live Activities, Dynamic Island and Maps
helper: coder

Files: new `Services/LiveActivity/RemedyActivity.swift` (shared attributes, must be in both the app and the widget target: put it where the widget can see it, or ask Dorron to tick the widget target membership), `RemedyWidget/RemedyWidget.swift` (the Live Activity UI), new `Core/DayChecklist.swift`, new `Core/FastingTimes.swift`, `Models/CarePlan.swift` (+ `arrivalTime: Date?`, `hospitalName: String?`, `hospitalAddress: String?`), `TodayViewModel.swift`, build settings key `INFOPLIST_KEY_NSSupportsLiveActivities = YES` (the only pbxproj edit allowed), new `RemedyTests/DayChecklistTests.swift`.

Brief:
- DayChecklist: what's due on a busy day (a stop day, day -1, day 0, discharge day). FastingTimes: turns "clear liquids until 2 hours before arrival" plus arrivalTime into clock times. Both pure.
- A Live Activity starts on busy days, lists what's next, and ticks off as the patient taps in the app.
- Day 0: Dynamic Island shows a countdown to arrival and the current step ("Clear liquids end in 1:42"), and a Directions button that opens Apple Maps to `hospitalAddress`.
- Arrival time and hospital come from the papers when present, else the patient types them on the Plan screen (both looks).

Done when: DayChecklistTests pass; DORRON checks in the Simulator that the sample plan starts one on day -1 and counts down on day 0.

---

## 3.6 Add the plan to Calendar
helper: coder (parallel ok)

Files: `Services/Reminders/CalendarService.swift`, `SettingsViewModel.swift`, `SettingsView.swift`, `SimpleSettingsView.swift`.

Brief: write-only calendar access. A Settings switch "Add my plan to Calendar" creates a "Remedy" calendar with surgery, stop days, visits and to-dos. Save event ids so changes update instead of duplicating. When the surgery date moves, move the events. Turning the switch off removes them. Never read other calendars.

Done when: moving the sample surgery date moves the events (DORRON checks in the Simulator).

---

## 3.7 Preview my first week
helper: coder (parallel ok)

Files: new `Interface/ViewModels/PreviewWeekViewModel.swift`, new Classic and Simple views in `Today/` and `Home/`, `Core/AppClock.swift` (read only unless a preview hook is needed).

Brief: before surgery, a "Preview my first week" button plays days 1 to 7 after surgery: for each day, the medicines, rules and visits, with Next and Back. It uses the plan's data with a preview date and never changes AppClock for the rest of the app.

Done when: it plays for the sample plan in both looks.
