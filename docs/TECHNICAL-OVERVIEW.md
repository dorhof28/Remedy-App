# Technical overview

How each feature is built. Paths are under `Remedy/` unless they start with another folder.

## Architecture

```
Core          pure rules: no SwiftUI, no SwiftData, fully tested
Models        SwiftData classes, all listed in RemedySchema.models
Persistence   saving (…Actions), model-to-Core adapters, the draft plan, demo data
Services      outside systems: AI, camera reading, MyChart, Health, reminders, widgets, backup
Interface
├── ViewModels        one per screen, shared by both looks; all words live here
├── Components        shared SwiftUI pieces (Kit, Plan, Papers, Readers, Bridges, App)
└── Screens
    ├── ClassicUI     tabs, lists, sheets
    └── SimpleUI      big tiles, one thing per page
App           RemedyApp, RootView, LaunchOptions, the look switch
```

Rules for where code goes:

- **Core is generic over protocols** (`PlanFacts`, `MedicineFacts`, `CheckItem` and others in `Core/PlanFacts.swift`). `Persistence/PlanFacts+Models.swift` makes the SwiftData models conform, and `Persistence/ModelAliases.swift` binds the generic types to them (`DayEvent`, `AgendaItem`, `ReminderItem`). Tests can run every rule on plain structs or on real models.
- **Views only draw.** A view reads a view model (`TodayViewModel`, `PlanViewModel`, …) built from the plan and `AppClock.now()`, and calls an `…Actions` enum in Persistence to save.
- **Every screen exists in both looks.** `RootView` picks the look from `AppLookMode` and the text size. Both looks use the same view models, so a rule or a word changes in one place.

## Clock

`Core/AppClock.swift` is the only source of "now". In demo mode it adds the demo day shift and fixed time from `LaunchOptions`. When the demo clock moves, `RemedyApp` posts `.demoClockChanged` and the root view redraws, so every screen reads the new time.

## Plan days

`Core/DayMath.swift` turns between dates and plan days. Day 0 is surgery day, negatives are before. Items store `startDay`, `endDay` and `dueDay` as offsets, so `PlanActions.setSurgeryDate` moves only `CarePlan.surgeryDate` and everything follows.

## Getting the papers in

`Interface/ViewModels/Scan/ScanFlowViewModel.swift` runs the whole flow as a `Step` state machine:

`welcome → addPapers → pages → (importPick) → paperDetails → reading → checkHidden → confirm → finish → (whatChanged) → (setup)`

### Camera and photos

1. `Components/Bridges` wraps VisionKit's document camera, the photo picker and the file importer.
2. `Services/Reading/PagePreparer.swift` finds the page rectangle with Vision, corrects the perspective and evens out lighting with Core Image.
3. `Services/Reading/TextReader.swift` reads the words with Vision's text recognizer. If a page reads poorly it reads again with shadows lifted.
4. `Core/PageStructure.swift` and `Core/PaperLayout.swift` rebuild columns, lists and wrapped lines from each word's position.
5. `Services/Reading/TypoFixer.swift` fixes obvious misreads with `UITextChecker`, never inside medicine names or numbers.
6. `Services/Reading/PDFReader.swift` takes text straight from PDFs that have it.

Optionally `Services/AI/Local/PageModelReader.swift` reads the page picture with a vision model too. Any number the two readings disagree on is shown to the patient (`Core/ReadAgreement.swift`).

### MyChart

- `Services/Epic/SMARTAuth.swift` signs in with SMART on FHIR (OAuth with PKCE, `PKCE.swift`) through `ASWebAuthenticationSession`. The token is kept in the Keychain.
- `FHIRClient.swift` reads MedicationRequest, Appointment (visits and the surgery) and DocumentReference (clinical notes, at most 10, newest first). Notes in text or HTML are downloaded or decoded from base64; HTML becomes plain lines through `PlainText.fromHTML`.
- `FHIRMapper.swift` turns the resources into a `DraftPlan`: an on-hold order becomes a stop, a PRN order becomes as needed.
- `Persistence/ImportPicks.swift` lists what was found as rows (visits and surgery, visit papers, medicines). The patient ticks what to keep on `ImportPickView`.
- Picked visit papers go through the same reading, hiding and checking as scanned pages. `DraftPlan.addingRecord` then merges the record: the papers always win; the record only fills empty fields and adds medicines and visits the papers don't name.

`Services/Health/HealthRecordsImporter.swift` does the same for Apple Health clinical records, medicines only.

### Hiding names before reading

- `Core/Redactor.swift` removes the names the patient typed (`Core/PatientNames.swift`, kept in the Keychain), header lines with MRN, date of birth, account and similar numbers, and returns a `RedactedPage` that remembers each hidden word so the patient can tap it to show or hide every copy.
- `Services/AI/AIRedactor.swift` adds names that Apple's on-device model or `NLTagger` finds, then looks again at the top and bottom of each page.
- `Services/Reading/PageBlackout.swift` draws black boxes over the same words on the page picture, using the word boxes from Vision.
- The `checkHidden` step shows the hidden pages. Nothing is sent before the patient continues.

### Reading the papers into a draft

- `Services/AI/ModelChoice.swift` stores the patient's two choices: who reads the page picture and who makes the plan.
- `Services/AI/PlanReader.swift` maps the choice to a reader. `ModelPlanReader.swift` works with any FoundationModels `LanguageModel`: Apple's on-device model, Private Cloud Compute, a downloaded MLX model (`Local/LocalModels.swift`), Claude (`ClaudeAdapter.swift`), or any OpenAI-compatible server (`OpenAICompatibleAdapter.swift`, which also covers a Mac on the home network found by `Local/MacConnector.swift`). Gemini uses its REST API (`Gemini/`).
- `AIPrompt.swift` and `PromptExamples.swift` build the prompt. The model answers in the `AIPlan` shape (guided generation, or a JSON schema for Gemini).
- `AIPlanConverter.swift` turns the answer into a `DraftPlan`. An item whose quote is not on the page, or whose day the page doesn't state (`Core/SourceCheck.swift`), goes to `draft.leftOut` with the reason instead of into the plan, so the AI cannot add something the paper doesn't say, and the patient can see what was left out.
- A failed or unreachable reader shows a plain error and a way to try another reader. It never switches to a cloud reader by itself.

### Confirming and saving

- The `confirm` step shows each draft item next to its quote. Only confirmed items are kept.
- `Persistence/PlanImporter.swift` saves the draft into SwiftData. A second paper joins the existing plan. `Core/WhatChanged.swift` compares the new paper with the plan for the *What changed* screen.
- `Persistence/PlanSync.swift` then refreshes reminders, the widget snapshot and the calendar.

## The paper check

- `Persistence/PaperCheckInput.swift` turns every medicine line from every paper into a `CheckItem` with the paper's source (surgery team or another doctor) and printed date.
- `Core/MedicineIdentity.swift` matches the same medicine under generic and brand names (`Core/MedicalWords.swift` holds the brand list).
- `Core/PaperCheck.swift` compares each pair: action (take vs stop), stop day, dose. Each finding is green, blue or red.
- `Core/NewerPaperRule.swift` decides when a newer paper wins on its own: only when it is from the surgery team for the days it covers, or printed a month or more later. A paper with no printed date never wins on its own. Papers that beat each other in a circle are all held until the patient picks.
- `Persistence/PaperCheckReport.swift` caches one report per plan and is the one place the check meets the other rules: `slotsWithCheck`, `itemsWithCheck` and `answerWithCheck` give doses, reminders and Ask only the paper line the rules follow on each day (`followed(_:onDay:)`). While papers beat each other in a circle no line is followed, until the patient picks or saves the office's answer (`PaperCheckNote`).
- `Services/AI/CheckExplainer.swift` may reword a red card's two quotes in plainer words. It only explains; the card and its color come from the rules.

## Doses

- `Core/DoseSchedule.swift` gives the dose times for a medicine on a day, the state of each (upcoming, due, missed, taken, skipped), and the as-needed status (taken today, next allowed time, daily maximum reached).
- The first dose at home starts from the last dose given in the hospital (`lastGivenAt`, read by `Core/LastGivenParser.swift`), and paper times too close to it are skipped.
- `Persistence/DoseActions.swift` logs a dose. A second answer for the same dose changes the first log. Every log returns an undo token. A dose the patient corrects is marked `changedByYou`.

## Today

`ViewModels/Today/TodayViewModel.swift` builds the screen from the plan and now: the hero card (due dose, surgery-morning words, or the next visit), missed doses, later today, to-dos and red cards. `TodayHero.swift` picks the hero; `Core/PlanAgenda.swift` orders the day. Classic draws it in `Screens/ClassicUI/Views/Today`, Simple in `Screens/SimpleUI/Views/Home`.

## Ask

1. `Core/AskAnswers.swift` answers with word rules in a fixed order: danger words (call 911 or the surgeon), a named medicine (with every paper that mentions it), an instruction topic, visits, what to take today, and finally "not on your papers, call the office".
2. `Services/AI/Ask/SmartAsk.swift` runs those rules first. Only when they find nothing, the on-device model picks which line of the papers answers (`AskPicker.swift`); the answer shows that exact line.
3. `ViewModels/Ask/AskViewModel.swift` builds the suggested questions from the plan, so each one has an answer.

## Reminders, calendar, widgets, Siri

- `Core/ReminderPlan.swift` works out every notification (doses, stop days, visits, to-dos, check-in) with stable ids, capped at 60 to stay under iOS's limit of 64. `Services/Reminders/NotificationService.swift` schedules them; notification buttons log doses.
- `Services/Reminders/CalendarService.swift` writes visits to a Remedy calendar and to-dos to Reminders, after the patient agrees.
- `Services/Widget/WidgetSnapshotMaker.swift` saves the next dose and today's items to the app group; the widget extension reads them.
- `Services/LiveActivity/` starts a Live Activity on busy days.
- `Services/Siri/RemedyIntents.swift` adds *What do I take now?* and *I took my medicine* as App Intents.

## Check-ins and photos

- `ViewModels/CheckIn/CheckInViewModel.swift` saves pain (clamped to 0–10) and a note. A second check-in on the same day edits the first. Pain 8 or more shows the surgeon's number.
- `PhotoTrack` and `PhotoEntry` keep wound photos on the phone. The app never analyses them.

## Sharing

- `ViewModels/Share/SharePlanViewModel.swift` and `FamilyShareViewModel.swift` build the sheet for each `ShareChoice`.
- `Services/Sharing/FamilySheetPDF.swift` draws the SwiftUI page (`FamilySheetPage`) into a PDF with `ImageRenderer`; `FamilySheetPaginator.swift` splits long sheets so nothing is cut. The patient's name is printed only when they switch it on.
- `MistakeReport.swift` makes a short report about one wrong item.

## Backup

`Persistence/BackupSnapshot.swift` copies every model to Codable structs, keeping links by id. `Services/Backup/BackupFile.swift` encrypts the JSON with AES-GCM (CryptoKit) using a key derived by PBKDF2-SHA256 (600,000 rounds, random salt). Restore reverses it and rebuilds the links.

## Demo mode

- `Persistence/Demo/DemoScenarios.swift` defines 15 fake patients, each dated from today so it always shows the phase it names.
- `Persistence/Demo/DemoPatient.swift` (`DemoMode`) moves the real plan aside, loads the fake one, and puts the real plan back when demo mode ends.
- `Persistence/Demo/SamplePlan.swift` is the Avery Quinn knee replacement used for screenshots.
- `Services/Epic/SampleFHIR.swift` is a fake MyChart record in real FHIR JSON.

## Tests

`RemedyTests/` (Swift Testing):

| File | Covers |
|---|---|
| `PaperRuleTests.swift` | Paper check colors, rule 6, notes, gaps |
| `WordsAndDatesTests.swift` | Day math, words, phone and date parsing, fasting times, medicine names |
| `ImportAndPrivacyTests.swift` | FHIR mapping, import picks, record merge, redaction, patient names |
| `PlanStoreTests.swift` | Saving, joining papers, backup round trip, every demo plan |
| `ActionTests.swift` | Dose log and undo, as-needed limits, edits, contacts, to-dos, check-ins, moving surgery |
| `PlanBehaviorTests.swift` | Red cards, reminders never in the past, Ask quotes are real, suggestions name real medicines |
| `ScreenTests.swift` | Every main screen drawn in both looks for all 15 demo patients; view models at morning, afternoon and night; every share PDF |
