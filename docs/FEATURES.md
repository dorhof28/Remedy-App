# Features

Every screen exists in two looks. **Classic** is a standard iOS app with four tabs. **Simple** has big buttons, plain words and one thing per screen. *Automatic* (the default) picks Simple when the phone's text size is one of the accessibility sizes. Screenshots are in [app-media/](app-media/).

## Getting the papers in

- **Scan** with the camera. Remedy finds the page edges, squares the page and evens out shadows before reading it.
- **Photos, PDF or Files.** PDFs with text are read directly; scanned PDFs are read like photos.
- **MyChart** (Epic, SMART on FHIR). Brings in the surgery date, visits, the medicine list and visit notes. The patient picks which items to keep.
- **Apple Health records.** Brings in the medicine list.
- **Add papers later.** A new paper joins the existing plan, and *What changed* lists what is new, changed, restarted or not mentioned.

## Reading and privacy

- **Who reads the papers** is the patient's choice: iPhone only (camera reading plus Apple's on-device model or a downloaded model), Apple Private Cloud Compute, a model on their own Mac, or a cloud AI with their own key.
- **Names and IDs are hidden first.** The typed name, names the phone finds, MRN, dates of birth and similar header lines are removed. On the page picture they are blacked out.
- **Check what will leave.** Before any page goes to a cloud reader, the patient sees the hidden version and can tap a word to hide or show it.
- **Confirm every item.** Nothing goes into the plan until the patient says it matches the paper. Each item keeps the paper's exact words.

## The paper check

When two papers mention the same medicine, Remedy compares them:

- **Green** — they agree.
- **Blue** — a newer paper replaced an older one under a clear rule, for example the surgery team's newer paper covers the days after surgery.
- **Red** — they disagree and no rule decides. Remedy does not pick. The card shows both quotes and a button to call the office. The patient can save the office's answer.
- **Note** — only another doctor's paper lists a medicine. A calm note suggests asking the surgeon.

## Every day

- **Today** shows the dose due now with *I took it* / *Not now*, missed doses ("Don't take an extra one to catch up"), and the rest of the day.
- **Medicines** groups medicines into only when needed, every day, stopped for now and finished. As-needed medicines show *You can take 1 now* or the time of the next allowed dose, and stop at the daily maximum.
- **Medicine detail** shows the instructions, the end date, the paper quote, and earlier doses. *Something looks wrong* lets the patient fix the item or send a short report to their care team.
- **Plan** shows the next visit (call, directions, add to calendar), rules like *No driving*, and a timeline of stop, restart and surgery days.
- **Surgery day** shows arrival time, where to go, when to stop eating and drinking, and the hospital address.
- **To-dos** from the papers, with due days.
- **Check-in**: pain from 0 to 10, a note, and an optional photo of the cut that stays on the phone. A pain of 8 or more shows a call button.

## Asking

**Ask** answers questions about the papers only. Each answer shows the exact words from the paper. A question the papers cannot answer gets "call your surgeon's office" with the number, never a guess.

## Help and sharing

- **Help** has Call 911, the care team's numbers, and *When should I call?* warning signs from the papers.
- **Emergency info** writes a short Medical ID text and can make a Wallet card.
- **Share** makes a PDF for family: the full plan, a week, one day with boxes to tick, the medicine list, or an emergency card. The patient's name is printed only if they choose.

## Reminders and the rest of the phone

- **Reminders** for doses, visits, to-dos and the daily check-in. Notification buttons log a dose without opening the app.
- **Calendar and Reminders apps** get visits and to-dos on a Remedy calendar, if the patient says yes.
- **Widgets, Live Activity and Siri** show the next dose and busy days and answer "what's next".
- **Read aloud** on Simple screens.
- **App lock** with Face ID or passcode, off by default.
- **Backup** to a password-locked file and restore from it.

## Demo mode

Settings → Demo mode loads one of 16 fake patients (HSS knee replacement with its 4 sample papers, surgery in 10 days, surgery tomorrow, papers that disagree, many stop medicines, and more) and can move the fake clock. The real plan is kept safe and comes back when demo mode is turned off.
