# Bugs Found During the Screenshot and Docs Pass (Nov 15, 2026)

Found by the helpers that took the HSS demo screenshots and read the code for the website docs. Items marked **Fixed** were fixed on Nov 16; the rest are still open. They're sorted roughly by how much each one matters for patient safety and for the demo.

## Safety and trust

1. **Disagreement text contradicts itself.** A red card says Remedy "doesn't pick", and also that "Remedy follows the paper from Dr. Samuel Okafor". Reminders quietly follow a default line (the surgery team's paper, else the newer one). The Stopped list shows Eliquis "Last dose Sat, Nov 7" with no disagreement mark. (`before/classic-03`, `06`, `07`) **Fixed:** the card now says reminders use one paper and Remedy can't tell which is right.
2. **Ask gives the before-surgery Eliquis answer on day 4.** It ignores the discharge order to take it twice a day from Nov 14. **Fixed:** Ask skips disagreements whose days are over and answers from the line that was asked about.
3. **Simple's missed-dose card** ("Missed · 9:00 AM Take 1 Apixaban") has only "I Took It". There's no "I missed it" choice and no "don't take an extra one" warning. Classic does both. **Fixed:** it asks the question with Yes and No and logs Yes at the time the dose was due.
4. **Simple check-in** says "Your papers don't list warning signs", but Help lists six. Pain 9 on page 1 shows no call button. **Fixed:** the demo papers' warning signs are in, and pain 8 or more shows the call button.
5. **Delete All Data leaves things behind:** check-ins, wound photos, saved office answers and names to hide. The confirm text says everything is removed. **Fixed.**
6. **Private Cloud page reading** can send the page before the "check what will leave" step.
7. **Reminders can go over iOS's 64 limit.** There are 60 dose reminders plus one per red disagreement, with no cap.
8. **Heart doctor's own dates clash.** The quote says "last dose on the morning of 11/10", but the app shows "Last dose Sun, Nov 8". The clash inside one paper isn't flagged. **Fixed:** the sample letter now says the last dose is 11/9.
9. **Ondansetron on day 1 at 4 PM** says "Last one at 9:15 PM", which is still in the future, then "next at 5:15 AM".
10. **A 9 PM dose can be logged at 4 PM** with no early-dose warning.

## Demo and data

11. **Demo dates are one day early.** HSS knee rebases surgery to today − 4 (Nov 11 today), but the PDFs say Nov 12. Visits show a day early, and Eliquis "Starts Fri, Nov 13" against the paper's "November 14". The fix is to keep the papers' fixed dates and move the pretend clock. **Fixed:** the demo keeps the papers' dates and moves the clock.
12. **Medicines on more than one paper are listed twice:** Metoprolol, Atorvastatin, Calcium, Vitamin D3, Multivitamin, plus NSAIDs in My Day and Naproxen in a day view. "Before surgery paper" also appears twice under apixaban.
13. **"Stop Apixaban" appears twice** on the timeline (Nov 8 and Nov 9), and the surgery day view says "Stop today" for medicines stopped days earlier. **Fixed in the timeline; "Stop today" on the surgery day view is still open.**
14. **"How Papers Are Read"** lists "Names to Hide: Diane Morales" (another demo patient) for Ruth.
15. **Help lacks home care and the pharmacy**, though the discharge paper lists both.
16. **The Simple Papers screen shows the after-surgery paper (Nov 12)** 5 days before surgery, including on What Changed.
17. **Surgery-day Today never changes during the day.** At 6 PM it still shows "Rules this morning". It also doesn't show the 6 AM arrival or the sip-of-water morning medicines.
18. **Your Surgery page** shows the hospital and arrival time empty, though the footer says the papers filled them in.
19. **Today's past visit stays "Next visit"** after its time (home PT at 11 AM, still next at 2 PM).
20. **The widget ignores the demo clock.**
21. **Demo Mode shows "Off" in Simple Settings** and "On" in Classic for the same launch. **Fixed.**

## Small things

22. Rule and "Still stopped" orders change between launches.
23. "Notes from the check" cards don't name the medicine, and the first card is blank.
24. "Your papers disagree – Tap to see both" on the apixaban paper screen does nothing.
25. Tapping "Still stopped" opens Medicines on All, not the Stopped filter.
26. Ask: stray doubled quote marks; "Sennosides 8. 6 mg"; still suggests "Can I eat after midnight?" after surgery.
27. Privacy says "Plan made by: on this iPhone".
28. Oxycodone: Simple says "4 left today" where 5 is expected, and shows "OK from 6:05 PM" in green while Classic says "Not yet".
29. The missed dose is green in Simple's list but orange in Classic.
30. Snooze is 10 minutes in notifications but "Remind Me in 30 Minutes" on Today.
31. The "Show my steps" switch asks Health for access, but steps never show anywhere.
32. The plain word for each pain score is an empty stub.
33. The Simple "Save check-in" button wraps onto two lines. The What Changed intro is clipped at the left edge.
34. `scripts/check.sh` is referenced but missing. `ui-rules.md` points to old Theme paths. A comment in AppLook says the default look is Simple, but it's Classic.
35. Simple is missing several Classic screens: dose log, wound photos, preview week, Something Looks Wrong, Log an Earlier Dose. That goes against the both-looks rule.

## Found in the retakes (Nov 16)

36. Surgeon's newest paper also says 3 days for Eliquis. It isn't clear which paper reminders really follow, and one Eliquis detail shows no disagreement mark. This is core paper-check logic, so it needs a careful look.
37. "Your papers disagree – Tap to see both" on a medicine's paper row does nothing.
38. Visit titles have their first letter cut off on the left (appointment detail).
39. The first card on "Notes about your papers" is blank.
40. Help describes Dr. Whitfield's office with before-surgery advice after surgery.
41. Simple My Day's missed-dose step has no Yes / No buttons; only the home card has them.
42. A medicine stopped days ago shows "Stop today" on the surgery day view.
