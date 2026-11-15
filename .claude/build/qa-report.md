# QA report (Simulator pass)

Screenshots: /private/tmp/claude-501/-Users-dorronhoffman-Developer-Remedy/6887d0ee-3f64-4584-93e4-63788a0ebd42/scratchpad/qa/ (called Q/ below).
Ran: iPhone 17 sim (iOS 27), launch args -demoSamplePlan / -demoPatient / -demoWelcome / -appLook, demoDay set with `defaults write` (launch arg -demoDay does not parse negatives). A throwaway XCUITest driver in the scratchpad tapped through.

## Features (Classic unless noted)
| Feature | Result | Shot |
|---|---|---|
| Ready for surgery, day -1 (both looks) | ok | Q/a2.png, Q/g1.png |
| Preview my first week (both) | ok, fixed double strength | Q/b1.png, Q/p2.png |
| Ask me on stop days switch + Yes/No question + "call" card | ok | Q/g1.png, Q/d2.png |
| Add plan to Calendar switch | ok (switch on, permission prompt allowed) | Q/d1.png |
| Share and print, Everything page, share sheet | ok | Q/j1.png, Q/j2.png |
| Plan: arrival time, hospital fields, checklist | ok, Simple tap targets enlarged | Q/h2.png, Q/u3.png |
| Live Activity | not visible in sim, open (real device) | - |
| Last-given row on medicine | row only shows when a paper gives a time; sample has none, not seen | - |
| Recovery check-in + call card (both) | ok | Q/l2.png, Q/y3.png |
| Report a mistake | ok (Simple medicine detail page 1) | Q/b3.png |
| Photo timeline | opens, add-item dialog ok; adding a photo needs camera/picker, open | Q/w3.png |
| Goals Done one (reps/sets) | ok, 1 of 2 then 2 of 2 | Q/y1.png, Q/l1.png |
| Face ID switch + lock overlay | ok, overlay shows on relaunch | Q/f1.png |
| Emergency info Copy, Wallet card | ok | Q/w1.png, Q/w2.png |
| Backup make (password sheet), Restore from Welcome | ok to the file picker; real file pick not tried | Q/c3.png, Q/h1.png |
| Paper-check cards (Frank, Lena) | red cards seen in Simple at 18:12; at 18:34 Lena card missing, see open | Q/pt-lena.png vs Q/i2.png |

## Full test run
Failed, one test: PaperCheckTests/lenaSurgeryFollowed (matches the missing Lena card). That area (PaperCheck.swift, CheckWording.swift) was being edited by another helper, so I did not touch it. Everything else passed. Earlier runs hung on a stuck simulator; a clean shutdown and boot fixed that.

## Fixed
- PreviewWeekViewModel.swift: "Aspirin 81 mg 81 mg" now "Aspirin 81 mg".
- HospitalDayFields.swift: Simple checklist rows were 24pt tall, now 56pt rows and bigger check.
- TodayViewModel.swift: same medicine listed twice (Marcus "Fish oil" twice on the stop card), now once.

## Open
- Lena demo: the "papers disagree about Apixaban" card was there at 18:12 and gone at 18:34 (Q/i2.png). PaperCheck / CheckWording / PaperCheckViewModel files were being edited by another helper at 18:33, so likely theirs. Recheck after their step.
- Arrival time picker shows the current time when no paper gives one (Q/u3.png). Looks like a real time. Design choice for Dorron (show empty until set?).
- Simple "More settings" opens the Classic settings sheet (Q/j2.png).
- Simple scan flow "Which papers?" uses a small nav Back button and list rows (Q/h2.png). Not big.
- Simple lock overlay "Unlock" button is small (Q/f1.png).
- Sample plan lists Acetaminophen under both "Every day" and "Finished" (Q/z2.png), sample data only.

## Simple look pass (phases 0 to 4)
| Screen | Simple | Shot |
|---|---|---|
| Welcome (Scan, Restore) | ok | Q/g1.png |
| Scan: which papers | open, small Back | Q/h2.png |
| Reader choice | ok | Q/j1.png |
| Home (before, day -1, after) | ok | Q/n1.png, Q/x1.png |
| Ready for surgery | ok | Q/n1.png |
| Preview my first week | ok | Q/p2.png |
| Medicines list | ok | Q/z2.png |
| Medicine detail + Read to me + Report a mistake | ok | Q/a1.png, Q/b3.png |
| Plan groups (Today, visits, to do, coming up) | ok | Q/r1.png to Q/r3.png |
| What changed | ok | Q/r5.png |
| Plan: hospital day, emergency, photos | fixed (checklist size) | Q/u3.png |
| Emergency info | ok | Q/w1.png |
| Photo timeline | ok | Q/v3.png |
| Daily check-in | ok | Q/y3.png |
| Ask | ok | Q/d1.png |
| Get help, When should I call, Share with family | ok | Q/t1.png, Q/u1.png, Q/u2.png |
| Settings (Face ID, reminders, calendar, backup) | ok | Q/e1.png, Q/e4.png |
| Paper-check cards and resolve sheet | open, see Lena above | Q/pt-frank.png |
