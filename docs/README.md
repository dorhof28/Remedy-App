# Remedy

Remedy turns a patient's surgery papers into a day-by-day plan on their iPhone.

Hospitals send patients home with several printed pages: what to stop before surgery, when to restart it, new pain medicines, wound care, visits, warning signs. The pages come from different people on different days and sometimes disagree. Remedy reads them, checks them against each other, and shows one thing at a time: what to take now, what to do today, and who to call.

## Who it is for

- Patients before and after a planned surgery, often older and often on pain medicine.
- The family members who help them.

## What it never does

- It never makes a medical decision with AI. Doses, stop and restart days, and conflicts come from tested rules in `Remedy/Core`.
- It never hides a disagreement between papers. Two papers that disagree show a red card that tells the patient to call the office.
- It never sends a page anywhere without hiding the patient's name and ID numbers first, and the patient sees the hidden page before it leaves.
- It never falls back to a cloud AI on its own. The patient picks where the papers are read.

## Docs

| File | What it covers |
|---|---|
| [FEATURES.md](FEATURES.md) | Every feature, as the patient sees it |
| [SPECS.md](SPECS.md) | Platform, targets, data model, privacy, limits |
| [TECHNICAL-OVERVIEW.md](TECHNICAL-OVERVIEW.md) | How each feature is built, file by file |
| [app-media/](app-media/) | Screenshots of every screen, both looks, with a fake patient |
| [ui-rules.md](ui-rules.md) | Visual rules for the screens |

## Sample patient

All data in screenshots and demos is fake. The sample plan (`Remedy/Persistence/Demo/SamplePlan.swift`) is Avery Quinn, a right total knee replacement at the made-up Riverside Orthopedic Hospital, with 555-01xx phone numbers. Launch a debug build with `-demoSamplePlan YES -demoDay 3` to open it on day 3 after surgery.
