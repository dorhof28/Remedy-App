# Making sample papers for Remedy

A guide for writing fake surgery papers that show off what Remedy can do. Give this file, plus one or two of the PDFs in `SamplePapers/demo/pdfs`, to any writer (a person or ChatGPT) and ask for new papers.

## The one rule: write real papers, not app papers

Remedy is built to read the papers patients really get. A sample only proves something if it reads like a real printout. So:

- Copy the **format and voice** of real hospital printouts (Epic "After Visit Summary", discharge summaries, clinic letters). Keep their noise: vitals, lab orders, portal blurbs, long generic medication lists, allergy lines, "Done Today", contact boxes.
- **Never add a line just to help the app.** No "take at 6 AM, 2 PM and 10 PM" unless a real office would print that. No "your last dose is on…" unless that doctor would write it. No made-up sections like "Your goals" or "To-do list". If a real paper would say "every 8 (eight) hours", say that.
- Mixed formats on one paper are normal and good: a numbered personal list *and* a long generic "Discontinue X days prior" list, bold drug names with no sentence, brand and generic names mixed, medicine names in capitals.
- Several papers from different doctors for the same patient and surgery. Real patients get 3 to 6.

## Fake data, always

- Every page, top and bottom, centered in red: **SAMPLE - NOT A REAL PATIENT**
- Fake patient name, fake MRN (8 digits) and CEID (like `HOS-QK4T-7R2M-W9PX`), shown in the header and footer like a real printout.
- Fake doctors. Phone and fax numbers only from **555-0100 to 555-0199**.
- Fake street addresses and ZIP codes. Links only to `example.org`.
- No real patient details, ever, even blacked out.

## Page layout to copy (Epic After Visit Summary)

1. Header: big light gray "AFTER VISIT SUMMARY", patient name with "MRN:", CEID line, the visit date and time with a calendar icon, the place with a pin icon, a gray square logo box at top right.
2. "Instructions from [doctor]": either the instructions themselves, or "Your personalized instructions can be found at the end of this document."
3. "Today's Visit": "You saw [doctor] on [weekday month day, year]. The following issues were addressed: …", a vitals grid (Blood Pressure, BMI, Weight, Height, Temperature, Pulse, Respiration, Oxygen Saturation), then "Done Today" with each test followed by gray "for [diagnosis]".
4. "What's Next": the date stacked on the left (NOV / 12 / 2026), the visit name on the right, then time, place, address and phone. Long visits (webinars) carry joining instructions.
5. "How to Contact this Office": text on the left, office name and address in capitals on the right.
6. "You are allergic to the following", "Vital Signs" table, the patient portal blurb.
7. "Your Medication List as of [date]": generic name in gray with the strength small ("apixaban 5 MG tablet"), "Commonly known as: BRAND", over-the-counter items in capitals ("FISH OIL ORAL"), a shaded box when two entries are the same drug.
8. Footer on every page: "Patient Name (MRN: 12345678) • Printed at [date time]" on the left, "Page 1 of 7" on the right.

Discharge papers add "Your Hospital Stay", and the medication list splits into **START taking**, **CHANGE how you take**, **CONTINUE taking**, **STOP taking**. Each drug has its sig ("Take 2 tablets (1,000 mg total) by mouth every 8 (eight) hours."), and often "Last time this was given: 1,000 mg on November 13, 2026 at 6:02 AM", "Start taking on: November 14, 2026", "What changed: …".

## What Remedy reads from papers

Every item keeps the paper's exact words, and the patient confirms each one before it goes in the plan.

**Surgery**
- The surgery or procedure name and date
- Arrival time and place, check-in desk, address
- Fasting: "nothing to eat after midnight", "clear liquids until 2 hours before arrival" (Remedy works out the clock time from the arrival time)

**Medicines**, each one as one of:
- *take* on a schedule: times a day, every N hours, clock times, with food, "every morning", "nightly"
- *take as needed*: every N hours, a daily maximum ("No more than 6 a day", "Max Daily Amount: 30 mg"), and why ("for nausea")
- *stop*: "7 days prior", "4 days before", "48 hours prior", "the evening prior", "the morning of surgery", "until your post op visit"
- *OK to take*: "Tylenol is OK to take before surgery"
- Restart and start dates: "Restart on 11/14/2026", "Start taking on: …", "resume 24 hours after surgery"
- Strength, amount, brand and generic names ("Commonly known as"), groups ("Any other NSAID", "All vitamins/supplements")
- Exceptions: "baby aspirin 81mg is permitted", "You can continue your vitamin D, calcium"
- **Last given in the hospital**: "Last time this was given: … at 11:40 AM". Remedy spaces the first home dose from it.

**Rules**: things allowed or not, with a time span. "No driving for 4 weeks", "No tub baths for 4 weeks", "You may shower 3 days after surgery", "Do not kneel".

**Warning signs**: "Call the office for a temperature greater than 101.5", "Call 911 for chest pain", each tied to the number on the paper.

**Visits**: the What's Next rows, follow-ups, physical therapy, nurse visits, classes and webinars, with time, place and phone.

**To-dos**: one-time tasks. "Please have your cardiologist send copy of recent testing/clearance to FAX…", "Pick up your rolling walker", "Shower with Hibiclens the night before".

**Daily goals**: repeated things like "Walk several times a day", "Exercises 3 times a day, 10 repetitions", "Ice 20 minutes 3-4 times per day".

**Contacts**: office numbers, after-hours numbers, the pharmacy, fax numbers.

## The paper check (the big demo moment)

When two papers talk about the same medicine, Remedy compares them. Build these in on purpose, the way they really happen:

- **Red, they disagree:** the internist's generic list says "Discontinue 3 days prior: Eliquis", the cardiologist says "Hold Eliquis 2 days before surgery". Remedy never picks; it shows both quotes and a call button.
- **Blue, a clear rule decides:** the surgery team's newer discharge paper ("Start taking on: November 14") covers the days after surgery, over the cardiologist's earlier "resume 24 hours after surgery".
- **Green, they agree:** two papers both say continue metoprolol the morning of surgery.
- **Note:** only one non-surgeon paper mentions a medicine. Remedy suggests asking the surgeon.
- **Same drug twice:** "ADVIL ORAL" and "ibuprofen 200 MG tablet" on one list. Remedy shows one medicine.

## What changed

Adding a newer paper later shows a "What changed" list: new, changed, restarted or no longer mentioned. A discharge paper after pre-op papers shows this well (restarts, new pain medicines, stopped NSAIDs).

## Everything else the papers feed

- **Today**: the dose due now with *I took it / Not now*, missed doses ("Don't take an extra one to catch up"), the rest of the day, visits today
- **Medicines**: as needed (with "You can take 1 now" or the next allowed time, stopping at the daily maximum), every day, stopped for now, finished
- **Plan**: next visit with call, directions and add to calendar; rules; a timeline of stop, restart and surgery days
- **Surgery day**: arrival, where to go, the food and drink cut-off
- **Check-in**: daily pain 0 to 10 and the warning signs from the papers; pain 8+ shows a call button
- **Ask**: answers only from the papers, with the paper's words; anything else gets "call your surgeon's office"
- **Help**: 911, the care team's numbers, "When should I call?" from the papers
- **Share**: a family PDF of the plan, a week, a day or the medicine list
- **Reminders**, widgets, Live Activity and Siri for doses, visits and to-dos

## A good set for one fake patient

1. **Internist pre-op After Visit Summary** (6-8 pages): personal numbered stop list, morning-of and night-before medicines, clearance fax to-do, long generic stop list, full medication list with a duplicate.
2. **Specialist clinic note** (cardiology, hematology or diabetes, 3-4 pages): a blood thinner or diabetes plan that disagrees with one other paper by a day or two.
3. **Surgeon pre-op instructions** (3-5 pages): date, arrival, fasting, skin prep, what to bring, ride home, exercises, when to call.
4. **Hospital discharge After Visit Summary** (5-8 pages): START / CHANGE / CONTINUE / STOP with last given times and restart dates, discharge instructions, warning signs, follow-up visits including one on the demo day.

## Prompt to paste into ChatGPT

> Using the attached sample PDFs as the exact format and voice, write a new set of 4 fake surgery papers for one fake patient having [surgery] on [date]. Follow PAPER-GUIDE.md: real Epic After Visit Summary format, no lines written just for an app, fake names, 8 digit MRN, 555-01xx phone numbers, example.org links, and "SAMPLE - NOT A REAL PATIENT" in red at the top and bottom of every page. Include one red disagreement between two doctors, one blue newer surgery team paper, a duplicate medicine on a list, as-needed medicines with a daily maximum, a last given time, restart dates, warning signs with numbers, visits, to-dos and daily goals. Write each paper in the markdown markup used in SamplePapers/demo/papers so it can be rendered with make-demo-pdfs.swift.
