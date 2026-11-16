# Expected answers: HSS demo papers (Ruth Callahan, SAMPLE)

Right total knee replacement on **Thursday, November 12, 2026**. Demo day is Monday, November 16 (day 4 after surgery).
The same answers are in the app as `Remedy/Persistence/Demo/RuthDrafts.swift`. Every quote there is checked word for word against these PDFs.

## How to show it

- **Already set up:** Settings → Demo mode → Start here → **HSS knee replacement**. Loads all four papers with surgery 4 days ago and the days since coming home already filled in.
- **Live upload:** turn Demo mode on, then add `pdfs/D1` → `D4` from Files. With Demo mode on, the past days fill in as soon as the papers are saved, so uploading at 2 PM shows the 6 AM Tylenol taken at about 6:03, not a list of missed doses.
  - **Read papers with → Your AI** (Demo mode screen): the AI picked in Settings, like Claude, really reads them. Compare its answer with this file.
  - **Read papers with → Expected answers:** no AI, the answers below every time. Any other paper shows an error instead of a guess.
- Testing in Xcode: launch with `-demoScenario hssKnee -demoTime 14:00`.
- **Show the papers:** Settings → Demo mode → **Sample Papers** opens each PDF in the app, with a Share button to save it to Files.
- Website screenshots (day 4, 2 PM, both looks) are in `docs/app-media/hss-demo/`.

## Paper by paper

| Paper | Who | Printed | What the app takes from it |
|---|---|---|---|
| D1 internist pre-op | Primary care, Dr. Elena Brooks | Oct 22 | Stop aspirin 325, vitamins and supplements 7 days before (vitamin D and calcium OK). Stop ibuprofen, naproxen and meloxicam 4 days before. Tylenol OK. No valsartan the evening before. Levothyroxine, metoprolol and omeprazole the morning of surgery with a sip of water. Atorvastatin and gabapentin the night before. **Eliquis: stop 3 days before.** To-dos: clearance fax, bring inhalers. Visits: webinar Nov 5, cardiology Dec 14. |
| D2 cardiology | Heart specialist, Dr. Samuel Okafor | Oct 30 | **Eliquis: hold 2 days before**, last dose the morning of 11/10. Restart 24 hours after surgery if the surgeon says it's safe. Continue metoprolol, including the morning of surgery. Continue atorvastatin. Warning signs: racing heart → office; chest pain or passing out → 911. |
| D3 surgeon pre-op | Surgery team, Dr. Daniel Whitfield | Nov 2 | **Eliquis: stop 3 days before.** All NSAIDs 4 days before. Arrive at 6:00 AM. Nothing to eat after midnight. Clear liquids until 2 hours before arrival. Don't shave for 3 days. Hibiclens shower. Walker. An adult takes you home. Exercises 2 times a day. Visits: webinar, surgery, post-op Dec 1. |
| D4 discharge | Surgery team, Dr. Daniel Whitfield | Nov 13 | **Start:** Tylenol 1,000 mg every 8 hours (last given 6:02 AM); Zofran as needed (last given 9:15 PM); oxycodone as needed, every 4 hours, max 30 mg (6 tablets), last given 11:40 AM; Senokot nightly. **Change:** Eliquis twice a day and valsartan every evening, starting Nov 14. **Continue:** 9 home medicines. **Stop:** fish oil, glucosamine, ibuprofen, meloxicam, multivitamin. Rules: no driving 4 weeks, shower from day 3, no tub 4 weeks, dressing on 7 days, TED stockings, no pillow under the knee. Goals: walk, PT exercises 3 times a day, ice. Visits: **home PT Nov 16 at 11 AM**, staples Nov 24, post-op Dec 1, cardiology Dec 14. Warning signs, after-hours number and pharmacy. |

## What each screen should show (day 4, 2:00 PM)

- **Paper check:**
  - **Red:** Eliquis before surgery. Dr. Okafor says 2 days; Dr. Brooks and Dr. Whitfield say 3. Both quotes and a call button. It's on Today only while those days are ahead (move the demo clock back to see it). By day 4 it has moved to the notes on the Papers screen, and there are no daily reminders about it.
  - **Blue:** after surgery, the discharge paper's Nov 14 Eliquis restart is followed over "24 hours after surgery".
  - **Green:** metoprolol the morning of surgery (D1 and D2 agree).
- **Today:**
  - Due now: 2:00 PM Tylenol.
  - **Missed:** "Did you take the 9 AM apixaban? Don't take an extra one to catch up."
  - Later today: valsartan 7 PM, Eliquis, Lipitor, gabapentin and Senokot 9 PM, Tylenol 10 PM.
  - Home PT visit at 11 AM today.
- **Medicines:**
  - As needed: oxycodone "You can take 1 now" (last one 8:10 AM, 6 a day max), Zofran, albuterol.
  - Every day: 16. Stopped for now: 10. Finished: the pre-op lines.
  - Simple look: "Apixaban · Missed 9 AM. Don’t take an extra one." then "Take 2 now" for Tylenol.
- **Medicine detail, then Dose log:** each dose taken 0 to 12 minutes late since Nov 13 (6:00 AM → "Took it at 6:03 AM"). Last night's Senokot shows **skipped**.
- **Check-in:** days 1 to 3 are filled in (pain 7 → 6 → 5, with short notes). Today's is open to demo; pain 8 or more shows the call button.
- **Plan:** next visit (home PT today), rules (no driving until Dec 10, no tub, shower OK), and a timeline from the stop days to the visits.
- **To-dos:** everything due before today is done. Pick up medicines (day 1) is checked off.
- **Goals:** walk 3, PT exercises 3, ice 4 on past days; 1 of each so far today.
- **Help:** 911, Dr. Whitfield's office 555-0142, after hours 555-0143, HSS Home Care 555-0150, pharmacy 555-0165, cardiology 555-0131.
- **Ask:** "Can I shower?" → yes, from 3 days after surgery, with the dressing on. "Can I drive?" → no, for 4 weeks. Anything not on the papers → call the office.
