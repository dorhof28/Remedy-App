# Remedy

iOS 27 SwiftUI + SwiftData app (Swift 5 mode) that turns a patient's surgery papers into a day-by-day plan. All patient data here is fake.

## Code layout
- `Core`: pure rules, no SwiftUI or SwiftData. `Models`: SwiftData, all listed in `RemedySchema.models`. `Persistence`: saving, model-to-Core adapters. `Services`: outside systems.
- `Interface/ViewModels` are shared by both looks. Views in `Screens/ClassicUI` and `Screens/SimpleUI` only draw.
- Every screen change goes in both looks (Simple: big buttons, one thing per screen, plain words).

## Working
- When applicable, Build and test with `scripts/check.sh build` or `scripts/check.sh test [TestStruct]`, not raw xcodebuild (it prints only errors and saves usage). However, if needed use xcodebuild to verify.
- Tests use Swift Testing. Never weaken or delete a test to get it passing.
- New stored properties must be optional or have a default, so saved plans still open.
- iOS 26 and 27 APIs may be newer than your training: check developer.apple.com rather than guessing.

## Safety
- Medical decisions are plain, tested rules in Core, never AI judgment.
- Never hide a disagreement between papers or silently fall back to a cloud AI.
- Fake data only (555-01xx numbers, "SAMPLE" on papers). No API keys in code, they go in the Keychain.
- No git commit without Dorron’s approval.

## Style
Comments short, lowercase, no punctuation, like `// next dose time from the last one`. Keep replies short.
