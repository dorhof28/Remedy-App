# Specs

## Platform

| | |
|---|---|
| OS | iOS 27.0 and later, iPhone |
| UI | SwiftUI |
| Storage | SwiftData, on the device |
| Language | Swift 5 mode, default actor isolation `MainActor`; pure rules in `Core` are `nonisolated` where they can be |
| Tests | Swift Testing, in-memory SwiftData |
| Bundle id | `com.dorronhoffman.Remedy` |
| App group | `group.com.dorronhoffman.Remedy` (app and widget share the next-dose snapshot) |

## Targets

| Target | Purpose |
|---|---|
| `Remedy` | The app |
| `RemedyWidgetExtension` | Home and Lock Screen widgets and the busy-day Live Activity |
| `RemedyTests` | Unit, flow and screen tests |

## Swift packages

| Package | Used for |
|---|---|
| `apple/foundation-models-utilities` | Any OpenAI-compatible server (a Mac on the home network, Groq, Mistral, OpenRouter, custom) as a `LanguageModel` |
| `anthropics/ClaudeForFoundationModels` | Claude as a `LanguageModel` |
| `ml-explore/mlx-swift-lm` | Downloaded models that run on the iPhone |
| `huggingface/swift-transformers` | Tokenizers and downloads for those models |

Apple's on-device model and Private Cloud Compute come from the FoundationModels framework. Gemini is called over REST.

## Data model

`RemedySchema.models` lists every SwiftData model. `CarePlan` is the root; deleting it deletes everything under it.

```
CarePlan
├── MedicineInstruction ── DoseLog
├── CareRule
├── CareTask
├── Appointment
├── DailyGoal ── GoalLog
├── CareContact
├── SourceDocument
└── Paper
ChatMessage, PaperCheckNote, PhotoTrack ── PhotoEntry, CheckIn
```

- Every item that came from a paper keeps `quote` (the paper's exact words), `paper` (before or after surgery) and `paperID`.
- Days are stored as offsets from surgery (`startDay`, `endDay`, `dueDay`), so moving the surgery date moves the whole plan.
- Dose times are minutes after midnight (`timesOfDay`).
- New stored properties must be optional or have a default, so saved plans still open after an update.

## Privacy and security

- Pages, plans, photos and check-ins stay on the phone. The database is not synced.
- A page goes to a cloud reader only when the patient picked one, after names and ID numbers are removed and the patient has seen the hidden version.
- Saved patient names, API keys and the MyChart token live in the Keychain.
- Backups are AES-GCM, with a key from the patient's password by PBKDF2-SHA256 at 600,000 rounds.
- App lock uses Face ID or the passcode through LocalAuthentication. Off by default.
- Health, calendar, reminders, notifications and contacts are asked for only when a feature needs them.

## Medical rules

All medical logic is plain Swift in `Remedy/Core`, covered by tests:

- dose times and states (`DoseSchedule`), as-needed gaps and daily maximum
- stop and restart days (`RestartRule`), fasting times (`FastingTimes`)
- the paper check (`PaperCheck`, `NewerPaperRule`)
- Ask answers (`AskAnswers`), warning signs (`WarningSigns`), reminders (`ReminderPlan`)

AI is used only to read pages into a draft, to find names to hide, to pick which paper line answers a question, and to reword a red card's quotes in plain words. It never decides a dose, a day or which paper wins.

## Debug launch options

Debug builds only (`LaunchOptions`, `#if DEBUG`):

| Option | Effect |
|---|---|
| `-demoSamplePlan YES -demoDay N` | Loads the Avery Quinn sample plan, today = day N after surgery (negative = before) |
| `-demoScenario <name>` | Loads one of the 16 demo patients (`DemoScenario`) |
| `-demoTime HH:mm` | Fixes the clock |
| `-demoWelcome YES -demoScreen importPick\|reader\|pages\|hardPage\|cloud\|setup` | Starts with no plan and opens one first-run screen |
| `-appLookMode classic\|simple\|automatic` | Picks the look |
| `-demoOpenSimpleScreen <SimpleRoute>` | Opens one Simple page, like `medicines` or `help` |
| `-demoOpenSimpleCheckIn YES` | With `-demoOpenSimpleScreen today`, opens Simple's check-in |
| `-demoOpenPlanPage checkIns` | Opens Classic's check-ins page |
| `-demoFakeAI YES` | Uses a fixed AI answer |
| `-skipPermissionPrompts YES` | Hides the lock, calendar and reminder setup steps |

## Build and test

```bash
scripts/check.sh build
```

```bash
scripts/check.sh test
```

`check.sh` prints only errors and failures. `REMEDY_DD=<path>` sets the derived data folder.
