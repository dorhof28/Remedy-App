# Phase 0: Groundwork

Goal: saved plans survive model changes, every item knows which paper it came from, sample data is labeled, and a new set of fake papers exists to test everything after this.

Order: 0.1, then 0.2, then 0.3 and 0.4 (parallel ok).

---

## 0.1 Saved plans keep opening
helper: engine

Files: new `RemedyTests/MigrationTests.swift`, new `RemedyTests/Fixtures/` (a saved store), `App/RemedyApp.swift` only if needed, `Models/RemedySchema.swift` only if needed.

Brief:
- Goal: a plan saved by today's app still opens after every later model change in this plan.
- Every later change in this plan is additive (new models, new optional or defaulted properties), which SwiftData migrates automatically. So don't add VersionedSchema copies of all 11 models now. That costs a lot and adds nothing until real users exist. Leave a short comment in `RemedySchema.swift` saying the rule: new stored properties must be optional or have a default, renames use `@Attribute(originalName:)`.
- Before any model changes in this phase, make a fixture: a test helper that saves the current sample plan (`Resources/SamplePlan.swift`) to an on-disk store, run it once, and copy the store files (including -wal and -shm, or checkpoint first) into `RemedyTests/Fixtures/plan-nov5.store`. Then disable or delete the helper so it doesn't rewrite the fixture.
- `MigrationTests`: copy the fixture to a temp folder, open it with the current `Schema(RemedySchema.models)`, check one CarePlan opens with the same medicine count as the sample plan, and that fields added later read as nil or their default.
- If the fixture can't be loaded from the test bundle, read it from the repo with a path built from `#filePath` (the Simulator can read the Mac's files).

Done when: `scripts/check.sh test MigrationTests` passes. It must keep passing after 0.2.

---

## 0.2 Paper records
helper: coder

Files: new `Models/Paper.swift`; `Models/Enums.swift`; `Models/RemedySchema.swift`; `Models/CarePlan.swift`; `Models/MedicineInstruction.swift`, `CareRule.swift`, `CareTask.swift`, `Appointment.swift`, `SourceDocument.swift`; `Persistence/DraftPlan.swift`; `Persistence/PlanImporter.swift`; `Interface/ViewModels/ScanFlowViewModel.swift`; `Interface/Screens/ClassicUI/Views/Welcome/ScanFlowView.swift`; `Services/Epic/EpicImporter.swift`; `Services/Health/HealthRecordsImporter.swift`; `Resources/SamplePlan.swift`, `SampleDrafts.swift`, `DianeDrafts.swift`; `RemedyTests/ModelTests.swift`.

Brief:
- New enums in `Enums.swift`:
  - `PaperSource`: `surgeryTeam` (surgeon's office, hospital, pre-admission testing, anesthesia), `specialist`, `primaryCare`, `hospitalRecord` (MyChart or Health list), `other`.
  - `PaperField`: `heart`, `kidney`, `blood`, `diabetes`, `lungs`, `other`. Only used when source is `specialist`.
- New `@Model Paper`: `id: UUID`, `kindRaw` (PaperKind), `sourceRaw` (PaperSource), `fieldRaw: String?` (PaperField), `doctorName: String?`, `printedDate: Date?`, `addedAt: Date`, optional `plan` relationship. Computed: `kind`, `source`, `field`, `isSurgeryTeam`, `sortDate` (printedDate ?? addedAt).
- Add `paperID: UUID?` to MedicineInstruction, CareRule, CareTask, Appointment, SourceDocument. Add `papers` to CarePlan (follow how its other relationships are declared). Add Paper to `RemedySchema.models`. All new properties optional or defaulted.
- `DraftPlan` gets `paperSource: PaperSource = .surgeryTeam`, `paperField: PaperField?`, `doctorName: String = ""`, `printedDate: Date?`. `PlanImporter.save` creates one Paper per draft and stamps its id on every saved item.
- Scan flow: after "Which papers?", add a step "Who gave you this paper?" with four big choices: "My surgeon or the hospital", "Another doctor" (then pick: Heart, Kidney, Blood, Diabetes, Lungs, Other), "My primary doctor", "Not sure" (maps to `other`). Then an optional doctor name field and an optional "Date printed on the paper" date picker with a "No date on it" choice. Logic in ScanFlowViewModel, the view only draws. The Simple look uses this same scan flow, so make the choices large and plain.
- EpicImporter and HealthRecordsImporter create a Paper with source `hospitalRecord`.
- Sample data: every existing sample item gets a Paper (surgeryTeam, printed date matching the sample's story) so nothing has a nil paper.
- Test in ModelTests: every item in the sample plan has a paperID that matches a Paper in the plan.

Done when: build ok, ModelTests and MigrationTests pass.

---

## 0.3 Sample data banner
helper: quick (parallel ok)

Files: `App/LaunchOptions.swift`, `Interface/Components/Components.swift`, `App/RootView.swift`.

Brief: add `static var isSampleData: Bool` in LaunchOptions, true when the sample plan or the pre-made sample drafts are in use (reuse the existing flags there). Add a small `SampleDataBanner` view in Components.swift: a capsule that says "Sample data", secondary color, small text. Show it at the top of RootView in both looks when `isSampleData` is true. Never shown after a real scan.

Done when: build ok.

---

## 0.4 New sample paper set
helper: coder (parallel ok)

Files: new folder `SamplePapers/` at the repo root (not in the app target): `papers/*.md`, `expected/*.json`, `records/lena-record.json`, `make-pdfs.swift`, `README.md`. New `Remedy/Resources/SamplePatients.swift` (drafts for the 3 patients, following the pattern in `DianeDrafts.swift`).

Brief: write 3 fake patients: 10 papers and 1 record. Every paper is plain and realistic, has "SAMPLE - NOT A REAL PATIENT" in the footer, fake phone numbers 555-0101 to 555-0199, and the hospital "Northfield General Hospital (SAMPLE)". Write each paper as markdown in `papers/`. `make-pdfs.swift` (run with `swift SamplePapers/make-pdfs.swift`) renders each to a one-page PDF with AppKit or Core Text, no packages.

Patient A, Marcus Bell, right knee replacement, surgery Mon Dec 14 2026:
- A1 heart doctor letter, Dr. Priya Raman (specialist, heart), printed Nov 20 2026: continue aspirin 81 mg once daily, do not stop before surgery; continue metoprolol succinate 25 mg every morning including the morning of surgery with a sip of water; continue atorvastatin 40 mg at bedtime.
- A2 surgeon pre-op sheet, Dr. Alan Whitfield (surgery team), Dec 1 2026: stop aspirin 7 days before surgery; stop ibuprofen (Advil, Motrin) and naproxen (Aleve) 7 days before; stop fish oil 7 days before; do not take lisinopril 10 mg the morning of surgery; nothing to eat after midnight, clear liquids until 2 hours before arrival, arrive 6:00 AM.
- A3 pre-admission testing sheet, Northfield pre-admission testing (surgery team), Dec 4 2026: stop ibuprofen (Advil, Motrin) and naproxen (Aleve) 4 days before; stop fish oil 7 days before; take metoprolol the morning of surgery with a sip of water.

Patient B, Lena Ortiz, gallbladder removal, surgery Tue Dec 22 2026:
- B1 surgeon sheet, Dr. Hannah Cole (surgery team), Nov 10 2026: stop apixaban (Eliquis) 5 mg 2 days before surgery; do not take metformin 500 mg the morning of surgery; continue atorvastatin 20 mg at bedtime; arrive 7:30 AM.
- B2 blood doctor letter, Dr. Victor Osei (specialist, blood), Nov 14 2026: stop Eliquis 3 days before surgery, no bridging injection.
- B3 diabetes doctor letter, Dr. Mei Tanaka (specialist, diabetes), Dec 16 2026: stop metformin 48 hours before surgery.
- B4 discharge paper, Northfield (surgery team, after surgery), Dec 23 2026: oxycodone 5 mg, 1 tablet every 4 hours as needed for pain, no more than 6 a day, "Last given in the hospital: 1:40 PM"; acetaminophen 500 mg, 2 tablets every 6 hours, "Last given: 11:00 AM"; restart Eliquis 5 mg twice daily on Dec 24; restart metformin when eating normally; follow-up with Dr. Cole Jan 5 2027 at 10:15 AM. It does not mention atorvastatin.
- `records/lena-record.json`: a MyChart-style medication list in the same shape `Services/Epic/SampleFHIR.swift` uses: apixaban 5 mg, metformin 500 mg, atorvastatin 20 mg, omeprazole 20 mg.

Patient C, Frank Delgado, hernia repair, surgery Thu Jan 14 2027:
- C1 heart doctor letter, Dr. Samuel Okafor (specialist, heart), Dec 28 2026: "You have a heart stent. Do not stop clopidogrel (Plavix) 75 mg for any reason unless I tell you." Continue aspirin 81 mg.
- C2 hospital standard pre-op handout (surgery team), Jan 4 2027, a generic list: "Stop all blood thinners 7 days before surgery, including aspirin, clopidogrel (Plavix), warfarin (Coumadin), apixaban (Eliquis)."; stop vitamins and supplements 7 days before; "You may take ibuprofen until 3 days before surgery."
- C3 primary doctor note, Dr. Rachel Kim (primary care), NO printed date: stop ibuprofen now, use acetaminophen 500 mg up to 3 times a day for knee pain.

`expected/<patient>.json` for each: the papers (file, source, field, doctor, printed date), every medicine line (paper, name, other names, action, start and end day relative to surgery, strength, quote), and these expected check results:
- A: aspirin blue, surgery team newer than heart doctor, A2 wins, stop from day -7. Ibuprofen and naproxen blue, same team, A3 newer, stop from day -4. Fish oil agree. Metoprolol agree.
- B: Eliquis red, blood doctor newer than surgery team by 4 days, ask by Dec 18 (day -4), reminders follow B1 until resolved. Metformin blue, diabetes doctor 36 days later (much later), B3 wins. After discharge: what changed lists Eliquis restarted, metformin restarted, oxycodone and acetaminophen new, atorvastatin not mentioned. Record gap: omeprazole on the record, on no paper. First home dose: next oxycodone OK at 5:40 PM, next acetaminophen OK at 5:00 PM.
- C: clopidogrel red and aspirin red (generic newer line never beats a specific one), ask by Jan 6 (day -8). Ibuprofen red (C3 has no printed date).
`SamplePatients.swift`: the three patients as DraftPlans (one per paper, with paperSource, paperField, doctorName, printedDate set) so the app can load them in demo mode the same way the Diane drafts load.

Done when: `swift SamplePapers/make-pdfs.swift` makes 10 PDFs, the JSON files parse, build ok.
