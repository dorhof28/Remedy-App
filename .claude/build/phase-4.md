# Phase 4: Everyday features

Order: 4.1, 4.2, 4.3, 4.4 (each parallel ok, different files), then 4.6, 4.7, then 4.8, then 4.5 last (it needs Dorron to create a target).

---

## 4.1 Recovery check-in
helper: coder (parallel ok)

Files: new `Models/CheckIn.swift` (+ RemedySchema), new `Interface/ViewModels/CheckInViewModel.swift`, new Classic and Simple views, a Today row in `TodayViewModel.swift` and both Today looks.

Brief: once a day after surgery: pain 0 to 10 and the warning signs from the patient's own papers (CareRule items that say when to call). Any ticked sign shows the call card with the right phone number from the paper. Remedy never says whether a symptom is serious beyond what the paper says. Save day, pain, signs, note.

Done when: a ticked warning sign shows the right number in both looks.

---

## 4.2 Report a mistake
helper: coder (parallel ok)

Files: new `Services/Sharing/MistakeReport.swift`, new `RemedyTests/MistakeReportTests.swift`, `ConfirmView.swift`, the Confirm part of `ScanFlowViewModel.swift`, `MedicineDetailViewModel.swift`, `MedicineDetailView.swift`, `SimpleMedicineDetailView.swift`.

Brief: a "Report a mistake" button on each item and on the Confirm screen. It builds a small report: the item as read, its quote, the redacted page text, which model read it, app version. Run everything through the existing Redactor. The patient shares it with the share sheet (email or AirDrop). No server.

Done when: MistakeReportTests show a report built from a sample with a name and record number contains neither.

---

## 4.3 Photo timeline
helper: coder (parallel ok)

Files: new `Models/PhotoTrack.swift` (PhotoTrack and PhotoEntry, image data with `@Attribute(.externalStorage)`, + RemedySchema), new `Interface/ViewModels/PhotoTrackViewModel.swift`, new Classic and Simple views, reuse the camera and `PhotosPicker`.

Brief: track anything over time (incision, swelling, rash): name a track, add dated photos with an optional note, compare two side by side, share a chosen set with the doctor. Photos stay inside the app, never saved to the photo library. Remedy never comments on the photos.

Done when: 5 photos over 2 weeks can be compared and shared in both looks.

---

## 4.4 More flexible daily goals
helper: coder (parallel ok)

Files: `Models/DailyGoal.swift` (+ `reps: Int?`, `sets: Int?`, `seconds: Int?`, `timesPerDay: Int?`), `Persistence/GoalActions.swift`, goal rows in both Today looks and their ViewModel.

Brief: a goal can be a count per day, sets and reps, and an optional timer, so home exercises fit ("10 heel slides, 3 times a day"). Simple: one big "Done one" button with the count.

Done when: a 10 reps, 3 times a day goal works in both looks.

---

## 4.6 Optional Face ID
helper: coder

Files: new `Services/Security/AppLock.swift`, `App/RootView.swift`, `SettingsViewModel.swift`, `SettingsView.swift`, `SimpleSettingsView.swift`, build setting `INFOPLIST_KEY_NSFaceIDUsageDescription` (only pbxproj edit allowed).

Brief: off by default. When on, the app locks when it goes to the background and unlocks with Face ID or the passcode (LocalAuthentication). Lock state in AppLock, RootView only shows the lock screen.

Done when: on, the app locks after going to the background in the Simulator.

---

## 4.7 Emergency info
helper: coder

Files: new `Interface/ViewModels/EmergencyInfoViewModel.swift`, new Classic and Simple views, `Services/Sharing/FamilySheetPDF.swift` (wallet card page).

Brief: apps can't write to Medical ID, so Remedy writes the text for it: recent surgery and date, current medicines from the papers (only what the plan says today), surgeon's phone. A Copy button and 3 short steps to paste it into Health > Medical ID and turn on Show When Locked. Plus a printable wallet card with the same text.

Done when: the text copies and the wallet card prints in both looks.

---

## 4.8 Backup file
helper: engine

Files: new `Services/Backup/BackupFile.swift`, new `Persistence/BackupSnapshot.swift`, new `RemedyTests/BackupTests.swift`, `SettingsViewModel.swift`, both Settings views.

Brief:
- No paid Apple account yet, so no iCloud sync. Instead an encrypted backup file the patient saves to Files and restores on a new phone.
- Snapshot every model in RemedySchema (including Paper, PaperCheckNote, HomeBottle, CheckIn, PhotoTrack photos) into Codable structs with relationships by id, with a format version number.
- Encrypt with a password the patient picks: PBKDF2 (CommonCrypto, at least 200,000 rounds, random salt) to a key, AES-GCM (CryptoKit). Wrong password gives a clear error, never a crash.
- Restore shows what's in the file (plan name, surgery date, counts) and asks before replacing the current plan.
- Settings rows: Make a backup, Restore from a backup. Simple: the same two big buttons.
- If Dorron later gets the paid account, iCloud sync is a separate step (all relationships optional), not part of this one.

Done when: BackupTests round-trip the sample plan with photos, and a wrong password fails cleanly.

---

## 4.5 Apple Watch
helper: coder

DORRON first: in Xcode, File > New > Target > watchOS > App, name it "Remedy Watch", companion to Remedy. Say done.

Files: the new watch target folder, new `Services/Watch/WatchBridge.swift` (WatchConnectivity on the phone side), `TodayViewModel.swift` (send the day's list).

Brief: the watch shows today's doses with "I took it", and the next as-needed time. The phone sends the day's list when it changes. A tap on the watch logs the dose through the phone using the same DoseActions. No logic duplicated on the watch beyond display.

Done when: logging on the watch shows on the phone (DORRON in the Simulator pair).
