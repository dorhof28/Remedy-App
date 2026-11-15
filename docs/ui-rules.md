# Remedy UI rules

Put this file at `docs/ui-rules.md`. Add this line to `CLAUDE.md`:
`Before any UI change, read docs/ui-rules.md and follow it. If a rule blocks the task, say so instead of breaking it.`

**Who we design for:** a tired caregiver or an older, anxious patient, the day after a hospital stay, maybe on big text, maybe with shaky hands. If a screen needs explaining, it is wrong.

## 1. Brand: use the tokens, never raw values

The logo is a glossy capsule, half mint and half white, on soft pink. The app should feel the same: calm, clean, a little warm. The source of truth is `Interface/Components/Theme.swift`. **Read it before you style anything.** Never type a hex, a point size or a corner radius in a view.

| Need | Use |
|---|---|
| Brand / tint / "next" | `Color.remedyTeal` (mint #158069 light, #2A9D82 dark) through `Tone.info` |
| Logo accents (fills, glows, illustrations only, **never text**) | `Color.logoMint` #7BD6C0, `Color.logoPink` #FCC3D5 |
| Page / card / tile / inactive | `.screenBackground`, `.cardBackground`, `.tileBackground`, `.inactive` |
| Status | `Tone.good / .caution / .stop / .neutral`. ViewModels pick a `Tone`, never a `Color` |
| Spacing, radius | `Spacing.screenEdge / betweenCards / insideCard / minTarget`, `Radius.card / tile` |
| Animation | `Motion.perform(reduceMotion) { … }`, `Motion.animation(reduceMotion:)`, `.slideIn(reduceMotion:)` |
| Card building blocks | `TopCard`, `SectionCard`, `CardEyebrow`, `ToneBox`, `StatTile`, `IconRow`, `InfoRows`, `DividedList`, `DateTile`, `StatusTag`, `CallButton`, `.cardStyle()`, `.helpButtons()` |
| Simple look | `SimpleScreen`, `FitOrScroll`, `SimplePagedList`, `SimpleTile`, `SimpleGroupButton`, `ReadAloudButton` |

Rules:
- **One brand color.** Red, orange and green only ever mean stop, careful and OK, and they always come with an icon and words.
- **Contrast traps I measured:** `remedyTeal` text on the pink `screenBackground` is **4.46:1**, just under Apple's 4.5:1 for text up to 17 pt. Put teal text on `.cardBackground` (4.86:1) or make it bold or 18 pt+. White text on dark-mode teal is **3.36:1**, which passes only for bold text. `logoMint` and `logoPink` on white are under 2:1, so they are decoration only.
- Text uses system styles (`.body`, `.headline`, `.title2` …), never fixed sizes. Body is 17 pt by default and nothing is ever smaller than 11 pt.
- If something repeats, move it into `Cards.swift` / `Components.swift`. Never copy a view into a second screen.

## 2. Apple HIG essentials (iOS 26)

- **Tap targets of at least 44×44 pt** (`Spacing.minTarget`). Apple's floor is 28 pt, but our users get 44, and 60 or more for the main action in the Simple look. Leave about 12 pt between controls.
- **Dynamic Type up to AX5.** Text must reach at least 200%. Test at the largest accessibility size: nothing gets cut off, nothing overlaps, and rows stack vertically. In Simple, `FitOrScroll` may scroll only at huge sizes.
- **Semantic system colors and Dark Mode.** Check every screen in light, dark, Increase Contrast and Smart Invert.
- **Standard navigation only:** `TabView` (Classic), `NavigationStack`, `.sheet`, `.confirmationDialog`, `.alert`. No custom tab bars, no hamburger menus, no custom back buttons except `SimpleScreen`'s big Back. Every swipe has a button that does the same thing.
- **SF Symbols** for every icon, sized by text style, so they scale with Dynamic Type.
- **Liquid Glass only on system chrome.** Tab bars, toolbars and sheets get it for free. Apple says: *"Don't use Liquid Glass in the content layer."* Cards are solid `.cardBackground`. No `.glassEffect` on cards, rows or text blocks. If one custom floating control truly needs glass, use the regular variant, use it once, and say why in a comment.
- **VoiceOver:** every control and every row has an `.accessibilityLabel` built in the ViewModel (`spokenLabel`), e.g. "Ibuprofen, 400 mg, next dose 2 PM, not taken yet". Group the parts of a card so they're read as one. Decorative images are hidden from VoiceOver.
- **Reduce Motion:** animate only through `Motion`. Use no auto-playing, looping, zooming or parallax motion. When Reduce Motion is on, movement turns into fades.
- **Haptics are rare and consistent:** `.success` when a dose or task is done, `.selection` when stepping through a list, and `.warning` / `.error` only for real problems. Nothing plays a haptic on every tap.
- **No timed UI.** Toasts and undo bars stay until the user dismisses them or acts. Nothing auto-dismisses before an older user can read it.

## 3. Intuitive by default

- **One primary action per screen**, visually loudest (`.borderedProminent`), and placed where the thumb reaches it. Everything else is secondary.
- **Plain words at about a 6th-grade reading level.** Write "Take 1 pill every 8 hours", not "PO q8h". Write "Stop taking", not "Discontinue". When the papers use a medical term, show the plain word first and the paper's word second.
- **Say what happens next.** Buttons are verbs ("I Took It", "Scan Papers"), never "OK" or "Submit".
- **Today must answer "what do I do now?" without scrolling** at the default text size.
- **Destructive actions need a confirmation** with `.confirmationDialog`, a `role: .destructive` button that names the thing ("Delete Ibuprofen plan"), and Cancel. Prefer Undo (`UndoBar`) for small things like un-logging a dose.
- **Help is never more than one tap away.** `.helpButtons()` on every Classic tab root and Help on the Simple home screen.
- **Errors say what to do,** for example "Couldn't read page 2. Try again in brighter light."

## 3b. Make it feel like Apple wrote it

- **Native containers first.** Settings, Privacy, the Help contacts and any plain list use `List` / `Form` (`.insetGrouped`), not custom cards. Custom cards are only for Today and the detail screens. Apple's own apps look "Apple" mostly because they *are* standard lists.
- **Titles:** use large navigation titles on tab roots and inline titles on pushed screens. Sheets have a title, **Done** (`.confirmationAction`) or **Cancel** (`.cancellationAction`), and use detents (`.medium`, `.large`) when the content is short.
- **One capitalization pattern, everywhere.** Buttons, navigation titles and tab names use title case ("Scan Papers", "I Took It"), the way Apple's apps do. Body text, footers and messages use sentence case. Flows start with **Get Started**, step with **Continue** and end with **Done**.
- **App voice:** calm, short and direct. Never say "we" ("Unable to read page 2", not "We couldn't…"), and drop "Oops". Use "my" and "your" sparingly and the same way everywhere. Say "tap", never "click".
- **Empty states** use `ContentUnavailableView` with one next step ("No Papers Yet" + **Scan Papers**). A screen is never blank.
- **Loading** shows `ProgressView` with words ("Reading page 2 of 3…") or `.redacted(reason: .placeholder)`. A spinner alone is not enough.
- **Text hierarchy** comes from system styles only: `.headline` for the row title, `.subheadline` + `.secondary` for detail, `.footnote` for sources. Times and doses use `.monospacedDigit()` so they don't jump.
- **Dates and times** always use `.formatted(...)` and never a hand-built string, so 12/24-hour time and locale work. All strings go in a String Catalog (`Localizable.xcstrings`).
- **Context menus and swipe actions** on medicine and task rows, always with a visible button that does the same thing.
- **Feel like part of iOS:** the widget, the Live Activity for surgery day, App Intents for Siri ("Did I take my ibuprofen?") and notification actions ("Took It" / "Snooze") use the same words and `Tone` as the app.
- **Test like Apple:** run an Xcode Accessibility Inspector audit and add `try app.performAccessibilityAudit()` to one UI test per main screen. Screenshot every screen at AX5, in dark mode and with Increase Contrast before calling UI done.

## 4. Consent everywhere

1. **Ask for each permission just in time.** Ask for the camera when the user taps Scan, for notifications when they turn reminders on, and for Health or Calendar when they tap that feature. Never ask at launch.
2. **Pre-permission screen (Apple's rules):** one plain sentence on why, with exactly **one** button labelled **"Continue"** that opens the system prompt. Don't use "Allow", don't add Cancel or Close, and don't show a picture of the alert. After a "Don't Allow", the feature shows a calm explanation and an "Open Settings" button, and the rest of the app still works.
3. **Purpose strings** in Info.plist (camera, notifications, Health, calendar) are full, active sentences ending with a period, e.g. "Remedy uses the camera to scan your hospital papers so it can list your medicines."
4. **Cloud AI consent gate.** Before any page text leaves the phone, show a screen titled "What the AI will see". It shows the redacted text with every hidden part visibly marked (names, dates of birth, MRN, CEID and similar), says where the text goes (Apple Private Cloud Compute) and that nothing is stored for training, and has two clear buttons: **"Send"** and **"Keep on This iPhone"** (on-device only). This is a legal-style consent, not a system pre-alert, so the two buttons are correct here. **Nothing is sent before the user taps Send.** Ask again for each new document.
5. **The user confirms every medicine** before it enters the plan (the Confirm flow). The AI never writes to the plan silently.
6. **Settings > Privacy** lists each permission and its state with a link to iOS Settings, the cloud-AI on/off switch, **Delete All Data** (confirmed with a destructive dialog), and **Clear chat**.
7. **No real patient data** goes in the app, previews, screenshots, tests or sample files. Use only the fake sample papers.
8. **Medical disclaimer** on the first run, in Settings, and pinned in Ask: "Remedy helps you read your papers. It doesn't replace your doctor." Ask answers only from the uploaded papers and shows the quote. When it can't, it says so and offers **"Call your doctor's office"**. Warning-sign questions (chest pain, trouble breathing, bleeding) skip the AI and show **Call 911** first.

## 5. Checklist (every UI change)

- [ ] Only `Theme` tokens, with no raw colors, sizes or radii
- [ ] Teal text sits on a card (or is bold / 18 pt+), and logo colors are never used as text
- [ ] Tap targets are 44 pt or more, and the main action is obvious
- [ ] Works at AX5 text, in dark mode and with Increase Contrast
- [ ] Every control has a VoiceOver label, and color is never the only signal
- [ ] Animation goes through `Motion`, and Reduce Motion is respected
- [ ] No glass in the content layer
- [ ] Plain words, with no abbreviations or jargon. Title case on buttons, and no "we"
- [ ] Lists use `List`/`Form`, empty states use `ContentUnavailableView`, and loading says what it's doing
- [ ] Destructive actions are confirmed or can be undone
- [ ] Permissions are asked just in time, with a one-button pre-screen
- [ ] Nothing leaves the device without the "What the AI will see" consent
- [ ] No real patient data, and the disclaimer and escalation are present where relevant
- [ ] No logic in views: ViewModels hold strings, `Tone`s and `spokenLabel`s

## 6. Review prompt (paste into Claude Code)

```
Read docs/ui-rules.md and Interface/Components/Theme.swift. Then review every
SwiftUI view changed since the last commit (git diff) against the rules, section
by section. For each problem give: file:line, the rule broken, why it matters for
an older or anxious patient, and the smallest fix that uses existing Theme tokens
and shared components. Check especially: raw colors/sizes, tap targets under 44pt,
layouts that break at AX5 Dynamic Type, missing accessibility labels, animation
outside Motion, glass in the content layer, jargon, unconfirmed destructive
actions, permission requests not tied to a user action, and any path where page
text could leave the device before the consent screen. Be blunt and rank by
severity. Do not edit files, commit, push or publish anything. Only report.
```

---
*Sources checked 2026-11-13: Apple HIG [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) (44/28 pt, 4.5:1 and 3:1, 200% text, Reduce Motion, color not alone), [Materials](https://developer.apple.com/design/human-interface-guidelines/materials) (no Liquid Glass in the content layer), [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy) (just-in-time requests, one-button pre-alert, purpose strings), [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics), [Writing](https://developer.apple.com/design/human-interface-guidelines/writing) (no "we", consistent capitalization, Get Started/Continue/Done, empty states). Contrast ratios were computed by hand with the WCAG formula. **Not verified:** that `logoMint` and `logoPink` exist with these exact names in your current Theme.swift (from project notes; the Mac wasn't reachable). The redaction field list and the Private Cloud Compute "not stored" wording should be checked against your real pipeline before the app claims them.*
