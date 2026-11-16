# Remedy: Features in Depth

Remedy is an iPhone app that turns a patient's surgery papers into a calm, day-by-day plan. It reads the pages a hospital sends home, checks them against each other, and shows one thing at a time: what to take now, what to do today, and who to call.

This page describes every feature as it works in the app today. Each section covers what the feature does for the patient, how it behaves, how the two looks (Classic and Simple) differ, and why it is safe.

All examples use Remedy's made-up demo patient, **Ruth Callahan**, who is having a right total knee replacement at the fictional **HSS Lakeside (SAMPLE)**. Every phone number is a 555-01xx test number. No real patient data appears anywhere in Remedy's demos or screenshots.

---

## Contents

1. [The ideas behind Remedy](#1-the-ideas-behind-remedy)
2. [Two looks: Classic and Simple](#2-two-looks-classic-and-simple)
3. [Getting the papers in](#3-getting-the-papers-in)
4. [Privacy: hiding names and choosing who reads](#4-privacy-hiding-names-and-choosing-who-reads)
5. [Checking every item](#5-checking-every-item)
6. [The paper check: when papers disagree](#6-the-paper-check-when-papers-disagree)
7. [Today](#7-today)
8. [Medicines](#8-medicines)
9. [Daily goals: walking, therapy, ice](#9-daily-goals-walking-therapy-ice)
10. [Daily check-in and pain](#10-daily-check-in-and-pain)
11. [Photos of the cut](#11-photos-of-the-cut)
12. [Plan, timeline, rules, to-dos and visits](#12-plan-timeline-rules-to-dos-and-visits)
13. [Getting ready for surgery](#13-getting-ready-for-surgery)
14. [Ask](#14-ask)
15. [Help, care team and emergency info](#15-help-care-team-and-emergency-info)
16. [Sharing and printing for family](#16-sharing-and-printing-for-family)
17. [Reminders, Calendar and the rest of the iPhone](#17-reminders-calendar-and-the-rest-of-the-iphone)
18. [Read Aloud and accessibility](#18-read-aloud-and-accessibility)
19. [Settings, app lock and backup](#19-settings-app-lock-and-backup)
20. [Demo mode](#20-demo-mode)
21. [Screenshots](#21-screenshots)

---

## 1. The ideas behind Remedy

Patients often go home with several printed pages from different people on different days: a primary care doctor's pre-op letter, a heart doctor's note, the surgeon's instructions, and the hospital's discharge papers. They do not always agree. Remedy was built around a few firm promises.

- **Medical decisions come from plain, tested rules, never from AI.** Dose times, how long to wait between pain pills, stop and restart days, and which paper wins are all worked out by written rules in the app, each covered by automated tests. AI is used only to read pages, find names to hide, find which paper line answers a question, and put a disagreement into simpler words.
- **Remedy never hides a disagreement.** When two papers say different things and no clear rule decides, Remedy shows both papers' exact words and asks the patient to call the office. It does not pick.
- **Nothing goes into the plan until the patient confirms it.** Every medicine, rule, visit and to-do is checked against the paper, one at a time.
- **Every item keeps the paper's own words.** Wherever Remedy tells the patient something, the original quote is one tap away.
- **The patient's name and ID numbers are hidden before anything is read off the phone,** and the patient sees exactly what will leave before it goes.
- **Remedy never quietly switches to a cloud AI.** The patient picks where papers are read. If that choice fails, Remedy says so and asks.
- **It helps, it does not replace the doctor.** The welcome screen, Settings and About all say: "Remedy helps you read your papers. It doesn't replace your doctor."

---

## 2. Two looks: Classic and Simple

Every part of Remedy can be drawn in two looks. Both read the same plan and use the same rules and words underneath, so they never disagree with each other.

**Classic** is a standard iPhone app with four tabs along the bottom: **Today**, **Medicines**, **Plan** and **Ask**. Help and Settings buttons sit at the top of every tab. It shows everything on the papers, with cards, lists and detail pages.

**Simple** is built for people who find phones hard to use. It opens on a home screen that shows the one thing to do now with one big button, followed by four large tiles: **My Day**, **Medicines**, **Ask** and **Help**. Text is large, buttons are big, there is one thing per screen, and words are plain. Simple uses calendar words such as "today", "tomorrow" or "Wednesday" rather than day counters, and Read Aloud buttons are built into its screens.

**Choosing the look.** In Settings, the patient picks **Automatic**, **Classic** or **Simple**. Automatic is the default. It uses Simple when the iPhone's text size is set to one of the extra-large accessibility sizes, and Classic otherwise. The first time Automatic switches to Simple, a one-time note explains why ("Your text is very large, so Remedy switched to the Simple look") and offers **Use Classic Instead**.

**How Simple's home screen picks its headline.** A fixed order decides the one line at the top: a dose due now, then a late dose, then a visit today, then something important tomorrow (a visit or a medicine to stop), then the next dose today, then tomorrow's first item, then anything later. Examples: "Now: take Acetaminophen", or "Tomorrow at 8:00 AM: stop Aspirin".

**Themes.** Both looks offer five color themes: Remedy (mint and pink, from the app icon), Ocean, Sunset, iOS Native and Graphite.

**Where Simple is deliberately smaller.** Simple keeps the daily essentials. A few Classic-only extras are listed in each section below.

---

## 3. Getting the papers in

Remedy starts with a short welcome ("Turns your hospital papers into a plan for each day") and three choices: **Get Started**, **Try Demo Mode** or **Restore Backup**. Setup asks for a first name ("A first name is enough. It stays on this phone, and Remedy hides it from papers before they are read.").

### Where the papers come from

- **Scan with the camera.** Uses Apple's document camera. Before reading, Remedy cuts the page away from the table, squares it up and evens out shadows. Page pictures stay on the phone.
- **Choose Photos.** Pick pictures of the pages from the photo library.
- **Choose a PDF (Files).** PDFs that already contain text are read directly. Scanned PDFs are read like photos.
- **Import from MyChart (Epic).** Signs in with SMART on FHIR and brings in the next surgery date, upcoming visits, the current medicine list and recent visit notes that contain readable text. Only the permissions needed for medicines, visits and visit papers are requested. The connection is currently set up against Epic's public test (sandbox) system.
- **Import from Apple Health records.** Brings in the hospital medicine list stored in the Health app.

After a MyChart or Health import, the patient picks which rows to keep (visits and surgery, visit papers, medicine list). "Imported items still go through the check, item by item."

### About this paper

For each paper, Remedy asks a few short questions, one at a time ("Question 1 of 3"):

- **Who gave you this paper?** Surgeon's office, the hospital when you went home, another doctor, or the pharmacy. For another doctor, a list of doctor kinds (heart doctor, family doctor, diabetes doctor and others) with the common ones first.
- **The doctor and the date printed on the paper.** Remedy fills these in from the letterhead when it can and says "Found on the paper" or "Not found, left blank". The patient can choose **No date on it**.
- **Before or after surgery?** The patient can answer, or choose **Not sure, let Remedy sort it**. Remedy then reads the page and says what it decided and why, quoting the words it used, for example: "Remedy decided after surgery because the page says 'discharge instructions'. Change it if that's wrong." If the patient's answer and the page seem to disagree, Remedy says so and asks them to pick.

### Reading safeguards

- **Hard pages.** If a page is too blurry to read, Remedy says "Page 2 is hard to read" and offers **Scan Page 2 Again** or **Skip This Page**, with a tip about light and framing.
- **Number repair, always disclosed.** Clear camera misreads inside doses and dates (such as "1O mg" for "10 mg") are fixed, and every fix is shown: "Remedy read '1O mg' as '10 mg'. Check it on the paper."
- **Two reads compared.** When an AI model reads the page picture, the phone's own camera reading runs too. Lines where the two disagree on a number are flagged for the patient to check.
- **Nothing made up.** Every medicine the AI returns must match words actually on the page. Anything that does not is left out and listed under "We left out 1 item", with what the AI said and why it was dropped.
- **Gaps are named.** If the read found no surgery date, no medicines, or no rules and to-dos, Remedy says so and offers to fix it.
- **Surgery date.** A labeled date such as "Date of surgery" beats the AI's guess, and a visit date at the top of a page is never mistaken for the surgery. If two different dates appear (for example, a typed date and a handwritten change), the patient picks. Remedy then asks "Is your surgery on Thursday, November 12, 2026?"
- **Abbreviations explained.** Short forms like "PO" or "q8h" get plain words under the quote.

### Adding papers later

Most patients get their discharge papers after their pre-op papers. **Add New Papers** sends a new paper through the same steps: hiding names, "What the AI will see", and the item-by-item check. The new paper joins the existing plan.

**What changed** then lists, compared with the plan:

- **New**: "Your newest paper adds these."
- **Changed**: "Your newest paper says something different about these."
- **Restarted**: "You were told to stop these. Your newest paper says to take them again."
- **Still stopped**: "Keep not taking these."
- **Not mentioned**: "Your newest paper does not say anything about these." This appears when a discharge paper from the same surgery team leaves out a medicine from an older paper. Remedy adds: "Something not mentioned on a new paper is never restarted on its own."

The **Papers** page (Plan, then More, then Papers in Classic; a Papers page in Simple) lists every paper with who gave it, the date printed and the page count. A paper can be opened to see its pages or deleted. Deleting asks first and removes only what came from that paper.

---

## 4. Privacy: hiding names and choosing who reads

### Names and ID numbers are hidden first

Before any reading happens, Remedy hides personal details on every page:

- The name the patient typed, every word of it, even if the camera misread a letter (for example "Smlth" or "0rtiz").
- Names found on the page by the on-phone AI, plus names in labeled fields and patient header lines (such as "SMITH, JOHN A MRN 123").
- Medical record numbers (MRN, CEID), dates of birth, home addresses, the patient's own phone numbers, email addresses and other long ID numbers.

On the page picture itself, those words are covered with black boxes, and barcodes are blacked out too.

Medicine words on a medicine line are protected from being hidden by mistake. In Settings, under **Names to Hide**, the patient can add other spellings or nicknames.

### Check what will leave

If the patient has chosen a reader off the phone, they see **What the AI Will See** before anything is sent: the page text with black bars over the hidden parts, and the blacked-out page picture. They can **tap any word to hide it or show it**. A short sheet explains: "Black parts never leave your phone." Nothing is sent until they tap **Send**, and "Remedy asks again for each new paper."

If the hiding AI was not ready and only the built-in rules ran, Remedy says so plainly: "They can miss some, so check the page closely."

### Who reads the papers

The patient chooses in three plain steps, each shown as one line: what reads the page, what hides names, and what makes the plan.

**1. Reading the words off the page** (always on the iPhone or Apple Private Cloud Compute)

| Choice | What it is |
|---|---|
| iPhone camera reading | Apple's on-phone text reading plus Remedy's own layout rules. Rebuilds lists and columns. Nothing leaves the phone. |
| GLM-OCR (download, about 1.6 GB) | A model made for reading papers. Best with lists and tables. Runs on the iPhone. |
| Gemma 4 (download, about 3.6 GB) | Reads papers and finds names to hide. Runs on the iPhone. |
| Gemma 4 Large (download, about 5.2 GB) | The sharpest. Needs an iPhone 17 Pro or newer. |
| Apple Private Cloud | Apple's private servers read the page. "Apple can't see or keep it." |

**2. Hiding names** (never a cloud AI): Apple Intelligence on the iPhone, a downloaded Gemma model, Apple Private Cloud, or fixed rules only. Fixed rules always run as well.

**3. Making the plan**

- **On this iPhone** (recommended): Apple's on-device model. Nothing leaves the phone.
- **Apple Private Cloud Compute.**
- **Your own Mac**, on the same Wi-Fi, running LM Studio, oMLX or Ollama. Remedy finds the Mac by its name, lists its models and picks the strongest one. Papers stay on the home network.
- **A cloud AI with the patient's own key**: Claude, Google Gemini, OpenAI, OpenRouter, Groq, Mistral, or a custom address. Keys are stored in the iPhone's Keychain, never in the app's code or settings. Remedy can test a key with a sample page. Where a provider has a free tier, Remedy warns: "On a free key, this company may use what it gets to improve its AI."

**What leaves, in one line.** Each choice is labeled "Nothing leaves this iPhone", "Only the checked text is sent", or "Checked text and a blacked-out photo are sent". The patient can choose to send text only.

**No silent fallback.** If the chosen reader cannot be reached, Remedy says so and offers choices such as **Try Again** or **Use On this iPhone instead**. It never switches to another AI on its own.

**Turning name hiding off.** A patient using a cloud AI can turn off "Hide names before reading", but only after a warning ("Your name, birth date and record numbers would go to the cloud AI you picked"). Apple's on-device reading still hides them, and the scan screens then show a "Names are not hidden" notice on every page.

---

## 5. Checking every item

After reading, Remedy shows **Check Your Plan**: "Nothing goes in your plan until you say it's right." Items come one at a time ("Item 3 of 12"), each with the paper's exact words and the page it came from. For each one the patient taps:

- **This Is Right**
- **Fix Something** (edit the name, dose, times, days or notes)
- **Leave It Out**

### Questions only the patient can answer

Remedy asks instead of guessing when the papers leave something open:

- **The hospital's last dose.** Discharge papers often say when a medicine was last given ("Last time this was given: 5 mg on November 13, 2026 at 11:40 AM"). Remedy copies that line word for word and uses it to set the first dose at home: the last hospital dose plus the gap the paper gives. If the paper leaves out AM or PM, Remedy asks "Was that AM or PM?" and does not use the time until answered.
- **"Did you already get this dose in the hospital?"** For twice-a-day medicines, Remedy asks whether a hospital dose counts as that day's dose. If the hospital dose came up to 6 hours before the first paper time, it asks "Does the dose you got at 6:40 AM count as your 9:00 AM dose?"
- **Surgeon's phone number missing.** "Your paper has no phone number for your surgeon. Add it so Call buttons work."
- **Arrival time and hospital**, if the papers don't give them.

The plan then opens on "Your plan is ready", with a short setup for app lock, Calendar, reminders and a check-in time. Each setup step explains why it is useful before Apple's own permission prompt appears, and offers a calm way out after a "no".

---

## 6. The paper check: when papers disagree

When two or more papers mention the same medicine, Remedy compares them with fixed, tested rules. Brand and generic names count as the same medicine (Eliquis and apixaban, Advil and ibuprofen), and a line about a group such as "any NSAID" counts for each medicine in that group. The result is shown as a color with words.

| Color | Meaning | What the patient sees |
|---|---|---|
| **Green** | The papers agree. | No action needed. Two papers saying the same thing show as one row. |
| **Blue** | A newer paper replaced an older one under a clear rule. | A note with the reason, for example: "Your newer paper is from your surgery team, so it replaces the older lines." |
| **Red** | The papers disagree and no rule decides. | Remedy does not pick. It shows both papers' exact words and a button to call the office. |
| **Note** | Only another doctor's paper lists a medicine and the surgery team's papers don't mention it. | A calm note suggesting the patient ask the surgeon's office, with **I asked the surgeon's office** to mark it done. |

### The rules, in plain words

- A newer paper wins on its own only if it comes from the **surgery team** (the surgeon's office or the hospital), or if it was printed **a calendar month or more later**.
- A paper with **no printed date** never wins on its own: "One paper has no printed date, so Remedy doesn't pick."
- Two papers printed **the same day** never win on their own.
- A line about a whole group of medicines never beats a line that names the medicine.
- A surgery team paper only covers its own period: a pre-op paper covers the days up to surgery, a discharge paper the days from surgery on.
- When three or more papers beat each other in a circle, no paper is followed until the patient picks one.

### Red cards

A red card says, in plain words, "Your papers disagree about Apixaban (Eliquis)", shows each paper's quote with the doctor and date, and offers **Call about Apixaban**.

- **When to call.** Remedy works out the day before the papers start to disagree and shows "Ask before Tue, Nov 10." On that morning at 9:00 AM, a reminder says "Your papers disagree about Apixaban (Eliquis). Call your surgeon's office about it today." If that day passes without an answer, the reminder repeats every morning at 9:00 AM. Once every day in question is in the past, the card leaves Today and stays on the Papers page, and the reminder stops.
- **Saving the office's answer.** **The Office Told Me Which One** opens a short sheet: "Which paper is right?", then "Who told you?" (surgeon's office, the hospital, someone else), and an optional note. Remedy then records "Confirmed by surgeon's office, Nov 9" on the medicine, and both papers stay in its history.
- **Until then.** The card stays red. Remedy says which paper reminders follow in the meantime, for example "Until you hear back, Remedy follows the surgery team's paper." In a circle of three or more papers, none is followed: "Remedy isn't following any of these papers until you choose."
- **Explain this.** When Apple's on-device model is ready, the patient can tap **Explain this**. The phone's AI rewords only the two quotes in simpler words, under the label "Simpler words, not advice", and adds: "Written by the phone's AI to help you understand. It does not decide anything. Ask your care team."

Red cards appear at the top of Today and on the medicine itself. In Simple, they appear as a "Do this first" card.

### In the demo

Ruth's four sample papers show every color. Her heart doctor's letter says to stop Eliquis 2 days before surgery, while her other papers say 3 days (**red**). Her discharge paper restarts Eliquis after surgery (**blue**). Metoprolol on the morning of surgery agrees across papers (**green**).

---

## 7. Today

Today answers one question: what do I do now? It changes shape before surgery, on surgery day and after surgery.

### The card on top

One large card leads the screen, chosen in this order:

1. **A medicine to stop today** (before surgery): "Stop today: Aspirin 325 mg. Don't take it from today on." with **I've Stopped It** / **I've Put Them Away**.
2. **Surgery morning**: "Arrive at 6:00 AM", the hospital name and address, and **Get Directions**.
3. **The dose due now**: "Due now · 2:00 PM, Acetaminophen 500 mg. Take 2 tablets." with **I Took It** and **Not Now**.
4. **The next dose today**: "Next · 10:00 PM".

A dose counts as **due** from 30 minutes before its time until 60 minutes after. After 60 minutes with no answer, it counts as **missed**. Doses due at the same time are logged together with one tap.

**Not Now** offers **Remind Me in 30 Minutes** or **I'm Skipping This Dose**, with the paper's reason and a reminder: "If you skip it, don't take an extra one later."

### Missed doses: never "take an extra"

A missed dose shows as a question, never an instruction: "Did you take the 2 PM acetaminophen?" with **Yes, I Took It** and **No, I Missed It**. The answer comes with "Don't take an extra one to catch up. Your next one is at 10:00 PM." Yes logs the dose at its scheduled time (the patient can then change the time). No marks it missed. Remedy never tells the patient to take a missed dose now, and this is covered by an automated test.

### The rest of the day

Under the card, short groups show:

- **Today's doses** by morning, afternoon and evening, with a progress ring ("3 of 5 taken today"). Tap to tick a dose. Ticked doses move into a "Done today" list.
- **Only when needed** medicines with "Can take one now, if needed" or "Next OK at 3:20 PM".
- **Still stopped** medicines ("Still stopped: 3 medicines").
- **To-dos** due today, with alert-style rows for anything overdue.
- **Daily goals** (see section 9).
- **Rules for today**, such as "No driving".
- **Daily check-in**.

### Undo

Every tap on Today (a dose, a skip, a to-do, "I've put them away") shows a short message such as "Logged Acetaminophen at 2:04 PM" with **Undo**.

### Evening heads-up

From 5:00 PM, Today adds a short "Get ready for tomorrow" card if a medicine stops tomorrow or a visit is before noon tomorrow. Otherwise Today shows only today.

### Stop-day question (optional, off by default)

With **Ask me on stop days** turned on in Settings, Today asks one gentle question on a stop day: "Did you take any Advil today?" "No" gets "Good. Keep not taking it." "Yes, I Took Some" gets "Your paper says not to. You may want to tell your surgeon's office." with a call button.

### Other states

- **No plan yet**: "Add your hospital papers to see what to do each day."
- **No surgery date**: "Every date in your plan counts from your surgery day. Your papers don't say it."
- **Surgery day, in the hospital**: "Follow your care team's instructions today. Remedy picks up again tomorrow with your recovery plan."
- **Plan finished**: once every medicine, rule, visit and to-do has ended, "Your plan is done." Stopped medicines are not counted, because they wait for the doctor.
- **See another day**: jump to yesterday, tomorrow or any date.

### Simple: My Day

Simple's home shows the one thing to do now with a big button in plain words: **I Took It**, **I Took One**, **I've Put It Away**, **Start Check-In**, **Done** or **Add It Now**. Labels read "Do now · 8:00 PM", "Missed · 6:00 AM" or "Next · 10:00 PM". **My Day** lists the whole day as plain instructions, with **Before** and **Next** to step through days, **Pick a Day**, **Back to Today**, and the note "Missed one? Don't take an extra one to catch up."

---

## 8. Medicines

### The groups

The Medicines tab sorts every medicine into groups:

- **Every day**: medicines taken at set times.
- **Only when needed**: as-needed medicines with their limits.
- **Stopped for now**: medicines to stop before surgery, or paused until the surgeon says it's OK.
- **Finished**: medicines whose last day has passed.
- **Not on your papers**: medicines from a hospital record that no paper mentions ("Ask your care team if you should keep taking this.").

A medicine whose papers disagree shows first in its group, with a warning. Classic has chips across the top ("All 7", then one per group) to jump between groups. The patient can rearrange the order of the groups, and the order is remembered.

Each row says where things stand in a few words: "8 AM taken · next 8 PM", "Missed 8 AM", "Both taken today", "OK now · 2 left today", "OK from 6:40 PM · 4 left today", "Restart Dec 3", "Last dose Wednesday", "Finished Nov 20". Times follow the iPhone's 12- or 24-hour setting.

### As-needed medicines: minimum hours and most per day

For medicines taken only when needed, Remedy applies two limits from the paper:

- **Hours between doses.** After a dose, Remedy waits this long before it says another is OK: "Not yet. Next one at 3:20 PM."
- **Most per day.** Once the limit is reached: "No more today (6 of 6)."

The hospital's last dose from the discharge paper counts like a logged dose. In the demo, Ruth's oxycodone 5 mg is "only for severe pain (7-10)", every 4 hours at most, no more than 6 a day.

When a dose is allowed, the card says "You can take 1 now" with **I Took One**. **Log an Earlier Dose** records a dose the patient forgot to tap. It accepts only times from midnight until now, and the wait counts from that time.

### Can I take...?

A search field at the top of Medicines answers "Can I take...?" by name, brand or plain word. Typing "Advil" finds ibuprofen. Typing "pain" or "blood thinner" lists what the plan has for that topic. Group lines are explained, for example: "Advil, Motrin and Aleve are the same kind of pain pill (NSAIDs). Your paper, page 3, says to stop them." A medicine that isn't on the papers gets: "'Benadryl' isn't on your papers. Ask before you take it."

### One medicine

The detail page shows:

- The instruction ("Take 2 tablets, 3 times a day"), the reason ("Helps prevent blood clots"), food notes, and other names ("Also called Tylenol").
- Start and end dates in calendar words.
- **Your paper says**, with the exact quote and plain words for abbreviations, and **Where this came from** (which paper, who gave it, the date printed, the page).
- Any paper check finding, in plain words.
- Earlier doses, with "given in hospital" marked.

**Something Looks Wrong** offers two paths: **Fix It Myself** (edit the item), or send a short **mistake report** to the care team. The report contains the item as read, the paper line, the page text and which reader was used. Every part passes through the name hider first, so names and record numbers are never included.

**Restarting a stopped medicine.** Remedy never restarts a stopped medicine on its own. **My Surgeon Said I Can Restart** asks who said it was OK (surgeon's office, another doctor, pharmacist) and when, then notes "Restarted, said OK by surgeon's office, Mon, Nov 23".

**Adding or editing a medicine.** The form checks entries before saving. An every-day medicine needs at least one time. Most per day must be 1 to 24, and hours between doses 1 to 48. A medicine can be deleted after confirmation.

### Dose log

**Every dose since surgery** lists each dose with its time and answer. "Tap a dose to change its answer or time. Changes are kept and marked." Edited entries show "changed by you".

### Simple

Simple's Medicines page shows the same groups as big rows, with a **Don't take** section. One medicine opens a single answer card with the verdict, **Show the Paper**, **More About It** and **I Took One**. Log an Earlier Dose, the dose log, restarting a medicine and Something Looks Wrong are currently Classic only.

---

## 9. Daily goals: walking, therapy, ice

Discharge papers often ask for things to do several times a day. Remedy turns these into goal tiles on Today, starting the day after surgery unless the paper says otherwise.

In the demo, Ruth has three goals:

- **Walk**, 3 times a day: "With your walker, a little farther each day."
- **Physical therapy exercises**: "The exercises your therapist taught you."
- **Ice the knee**, 4 times a day: "20 minutes, and after exercise."

Each tile shows progress ("1 of 3 today") and amounts when the paper gives them ("3 sets of 10 reps", "hold 30 seconds"). **Tap a tile to add one. Touch and hold to take one back.** The count never shows above the target, and the button changes to "Done one more" once the target is met. "Tap a goal to see how to do it, in your paper's words." A goal without a set time never shows as late.

---

## 10. Daily check-in and pain

A short daily check-in starts the day after surgery.

- **How much does it hurt?** A 0 to 10 scale: "0 is no pain. 10 is the worst."
- **Do you have any of these?** Warning signs taken from the patient's own papers ("These come from your own papers."). If the papers list none: "Your papers don't list warning signs. If something worries you, call your care team."
- **Anything to add?** An optional note "for yourself or your doctor".
- **Add a Photo of the Cut** (Classic), which "Stays on this iPhone".

**What happens at high pain.** A pain score of **8 or more** shows a **Call Surgeon's Office** button straight away. Ticking a warning sign shows a call card ("You ticked: calf pain, swelling or warmth") with the number from that sign's own paper line, the care team's number, or 911 if the paper says so. Numbers are listed with 911 first and without repeats. Remedy shows the paper's own words for each sign ("Your paper says: ..."), never a rating or advice. If no number was found: "No phone number was found on your papers. Look on your discharge papers."

A second check-in on the same day updates the first. Saving shows "Saved. See you tomorrow." and cancels that day's check-in reminder.

**Check-in time.** On the first open from surgery day, Today asks once for a reminder time (the default is 9:00 AM). If the patient taps Not Now, it asks once more two days later, and never more than twice. Reminders cover days 1 to 30 after surgery and skip days already checked in.

**Pain over time.** Classic's Check-ins page (Plan, then More) shows a pain chart with one point per day and a summary such as "Down from 6 on Monday to 4 today", plus notes, newest first. The chart is also described in words for VoiceOver. Simple shows "Pain over the last days" as a simple line. Both looks have the check-in itself.

---

## 11. Photos of the cut

Classic includes a photo timeline for anything the patient wants to watch over time, such as the incision.

- Photos are grouped into named series ("What do you want to watch?", for example "incision").
- Photos are taken with the plain camera or chosen from the library. They are stored inside Remedy only and never saved to the photo library. Large photos are shrunk to keep the app light.
- Each photo can have a note and is linked to that day's check-in ("Check-in: pain 3 of 10").
- The log reads newest first by day: Today, Yesterday, Nov 7.
- **Compare**: pick a before and an after photo to see side by side, with "6 days apart".
- **Share**: the chosen photos become a PDF, one page per photo, oldest first, with date and note.

"Remedy does not look at or comment on your photos. Show them to your care team." No AI ever looks at these photos.

The photo timeline is currently in Classic only.

---

## 12. Plan, timeline, rules, to-dos and visits

### The Plan tab (Classic)

From top to bottom:

- **Next visit**: the visit card with **Call**, **Get Directions** and **Add to Calendar**.
- **Rules** in effect now: up to three, with "not allowed" ones first, and **See All**.
- **Timeline**: every key day of the journey as one line of time, with a dot, the date and what happens that day (surgery, stop days, visits, to-dos, rule changes, medicines starting or finishing). Today is marked ("Today · day 3"). Tapping a day opens it.
- **To-dos** with their due days.
- **More**: Check-ins (pain and photos of the cut), Papers, Your surgery (date, hospital and times), and Share or Print Plan.

Because every date is stored as days before or after surgery, changing the surgery date moves the whole plan.

### Rules (instructions)

Remedy splits long paper instructions into short lines with a clear mark:

- **Do** (filled check), **Avoid** (outlined cross), **Fine** (outlined check). The shape changes as well as the color, so the mark reads without color.
- Lines are grouped by topic: Eating & drinking, Bathing, Moving & lifting, Driving, Wound care, Medicines, What to bring, and Other. "Avoid" lines come first in each topic.
- Lines are sorted into **now**, **later** (with when they start and end) and **done**.
- Each line opens to show the paper's exact words and where they came from.

Examples from Ruth's discharge paper: "No driving" (for 4 weeks and while taking narcotic pain medicine), "No pillow under your knee", "Showers with the dressing on" from day 3, and "No tub baths, hot tubs or swimming".

Simple shows these on its **Instructions** page.

### Days and the calendar

- **Pick a day** opens a calendar where every mark also comes with words on the day itself.
- **A day page** lists that day's visits, medicines, to-dos and rules, with **Before** and **Next**. Future days say "Day 7 after surgery · coming up. Nothing to do yet."
- Simple's **My whole journey** shows the key days as a list.

### Preview my first week

Before surgery, Classic offers **Preview my first week**: days 1 to 7 after surgery, one day at a time, showing what each will hold. "This is only a preview. Nothing here is saved or changed." Each day can be read aloud. The preview needs a surgery date and is currently Classic only.

### To-dos

To-dos from the papers ("Pick up your rolling walker", "Shower with Hibiclens the night before and the morning of surgery") appear on their due day and can be ticked off. The patient can add, edit or delete to-dos in both looks.

### Visits

Each visit shows the date, time and length ("Mon, Nov 16 · 10:30 AM · about 1 hour"), who you'll see, the place, **Call**, **Get Directions**, **Add to Calendar**, what to bring, and questions to ask ("Write the answers down, or ask if someone can come with you."). Visits can be added, edited and deleted in both looks. Deleting a visit also removes it from the calendar if it was added from Remedy.

### Your surgery

The surgery page holds the procedure name, date, hospital and arrival time. Choosing a hospital uses live map suggestions (no key and no location permission needed), with the hospital from the papers shown first.

---

## 13. Getting ready for surgery

### Before surgery

Before surgery, Today shows countdown wording ("Surgery in 4 days", "Surgery tomorrow"), stop days ("Stop today", "Still stopped"), and the to-dos for the days ahead. Each stop day sends an 8:00 AM reminder: "Stop today: Aspirin. Your papers say to stop 7 days before surgery. Put them away so you don't take one by mistake."

### Ready for surgery

On the day before surgery and surgery day, a **Ready for surgery** list collects:

- **Arrival time**, typed in by the patient or read from the papers ("Arrive at 6:00 AM").
- **Eating and drinking** worked out from the paper's words. "Nothing to eat after midnight" becomes a food stop at midnight. "Clear liquids until 2 hours before arrival" becomes "Clear liquids until 4:00 AM". After that time passes, the line changes to "Nothing to drink".
- **What to bring**, from the papers.
- The day's stops and to-dos.

Time-based rows are ticked by the clock, not by the patient. Remedy never makes up a "leave by" time, because it doesn't know travel time. If the papers lack an arrival time or hospital, Remedy asks for them, but only when surgery is 3 days away or less.

### Busy-day Live Activity

On busy days (a stop day, the day before surgery, surgery day and discharge day), a Live Activity can show the day's checklist on the Lock Screen and in the Dynamic Island. It includes a countdown such as "Clear liquids end in", and the next thing to do. Ticks are kept for that day only.

---

## 14. Ask

**Ask About Your Papers**: "Answers come only from your papers, with the exact words shown."

### How an answer is found

1. **Danger words come first.** Questions mentioning things like chest pain, trouble breathing, fainting or a stroke get: "This could be an emergency. Call 911 now. Don't wait for an answer here." Questions mentioning fever, bleeding, pus, a swollen calf, vomiting or a wound opening get: "This can be a sign of a problem after surgery. Call your surgeon's office now. If it feels serious, call 911." These lists are written down so a doctor can review them.
2. **Written rules** answer questions about a medicine, an instruction, visits, or what to take today, using the same line Remedy follows elsewhere. If two papers talk about that medicine, the answer says so and shows both quotes.
3. **If no rule matches**, Apple's on-device model may pick **one numbered line from the papers** that answers the question, matching meaning as well as words (for example, "a glass of wine" matches a rule about alcohol). It cannot write its own answer. The reply starts "Here's the closest thing on your papers." If the model thinks the question describes a symptom, the answer becomes "call your surgeon's office".
4. **If nothing on the papers answers it**: "I couldn't find that on your papers, so I won't guess. Your surgeon's office can answer it." with a call button.

**Ask never uses a cloud AI.** Under the answer, Remedy can note "Remedy did not send this question to the AI."

### Small touches

- Every answer shows the paper's exact words and which paper they come from.
- If two medicines are named, Remedy asks "Which one do you mean: Advil or Tylenol?" with buttons.
- Suggested questions are built from this patient's plan, so each one has an answer: "Can I take Advil?", "What do I take today?", "When can I start driving?", "When is my next appointment?"
- A reply that would repeat the last one word for word says "Same as my last answer".
- "Not for emergencies. If something feels wrong, call 911." Simple adds an **Emergency? Call 911** link under the box.
- Answers have **Read Aloud**. The chat stays on the phone and can be cleared ("Your plan stays.").

---

## 15. Help, care team and emergency info

### Help

- **Call 911**, for "trouble breathing, chest pain, fainting, heavy bleeding."
- **Your care team**: up to three people or places, with the surgeon's office first. Each has **Call**, and also **Message** and **Email** when they have a number or address. Numbers found on the papers are marked "from your papers". The patient can **Choose From Contacts** or **Type a Name and Number**.
- **When should I call?** Warning signs from the patient's own papers, each with a small picture and the right number. Common post-surgery signs are listed too (fever over 101°F (38.3°C), bleeding that soaks through the bandage, pain, swelling or warmth in the calf, a cut that is red, hot or leaking, pain medicine isn't helping, throwing up and can't keep medicine down), with the note that "your own papers may list others."
- **Emergency Info.**

In Classic, Help opens from a button at the top of every tab. In Simple, it is one of the four home tiles, with **Change Who to Call**.

### Emergency info

"Apps can't write to Medical ID, so Remedy writes the words for you." It writes a short paragraph to paste into the Health app's Medical ID: the recent surgery and date, the medicines to take now, and the surgeon's office number. It also gives three steps for pasting it in, ending with turning on **Show When Locked**.

**Make a Wallet Card** creates a printable, wallet-sized PDF card with the same facts and "From the papers the care team gave. Not medical advice. In an emergency, call 911." (It is a PDF to print and keep, not an Apple Wallet pass.) Allergies are not taken from papers yet, so the card says so plainly: "None on your papers. Tell the team if you have any."

---

## 16. Sharing and printing for family

**Share Plan** turns the plan into a PDF to print or send to family. The patient chooses:

| Choice | What it holds |
|---|---|
| **Full Plan** | Switches for medicines, visits and instructions, rules, to-do boxes, phone numbers, and on page two, check-ins and photos and the dose log. |
| **Week Plan** | Seven days from the chosen day, never past the end of the plan. |
| **One Day** | One day's doses and to-dos with **boxes to tick** on paper. |
| **Medicine List** | Every medicine. |
| **Emergency Card** | The short emergency summary. |

There's a page-by-page preview before **Share or Print**. Long lists continue onto more pages so nothing is cut off. **The patient's name is printed only if they turn on "Print my name at the top."** The sheet reminds them that "Shared files leave this iPhone."

Simple has its own family share page. Sharing is by PDF. There is no live syncing of the plan to other people's phones.

---

## 17. Reminders, Calendar and the rest of the iPhone

### Notifications

Remedy schedules reminders from the plan using written rules:

- **Doses**: one notification per time, naming every medicine due then ("Time for Acetaminophen and Eliquis"). For a single medicine, it gives the amount and reason. Up to 3 days ahead.
- **Notification buttons**: **I Took It** logs the dose without opening the app. **Snooze 10 Minutes** reminds again.
- **Stop days**: 8:00 AM on the day.
- **Visits**: 6:00 PM the evening before ("Tomorrow: Post Op Visit with Daniel Whitfield. 10:30 AM at HSS Lakeside Orthopedic Surgery. Bring: ...") and 2 hours before.
- **To-dos**: 9:00 AM on the due day.
- **Daily check-in** at the chosen time.
- **Papers disagree**: 9:00 AM calls to the office, as described in section 6.

Doses already given in the hospital are never reminded. Reminders cover up to 14 days ahead and stay under the iPhone's limit (at most 60 at a time). They refresh whenever the plan changes, and they show as banners even while the app is open.

### Calendar and Reminders apps

If the patient agrees, Remedy puts surgery, stop days, visits and to-dos into its **own Remedy calendar** and keeps it in step as the plan changes. "It never reads your other calendars." A single visit can also be added to any calendar the patient picks, with alerts the day before and 2 hours before. To-dos can go to a **Remedy** list in the Reminders app. Turning Calendar off removes every Remedy event and the calendar. Demo plans never go into the real calendar.

### Widgets

- **Remedy today** (small, medium, large, and Lock Screen rectangular, circular and inline): what to take or stop now, what comes next, doses taken ("2 of 5 taken"), the recovery day, and the next visit when no dose is coming. Stop-taking items are never the headline on the inline widget.
- **Remedy journey** (small, medium, large, Lock Screen rectangular): a countdown to surgery and the key days coming up.

### Siri and Shortcuts

- "What do I take in Remedy?" says what Today shows.
- "I took my medicine in Remedy" marks the doses due now as taken, or says "Nothing is due right now, so I didn't mark anything."

---

## 18. Read Aloud and accessibility

- **Read Aloud** reads screen text slightly slower than normal speech. It appears throughout Simple (home, My Day, Medicines, Ask, Help, check-in, plan) and on Classic's Ask answers, Ready for surgery list and first-week preview. Tap again to stop.
- **Simple look** for large text, chosen automatically at accessibility text sizes.
- **Dynamic Type** across both looks.
- **VoiceOver**: rows have spoken labels and hints ("Double-tap to mark as taken"). Charts are described in words ("Pain over time. Latest 4 of 10 on Monday.").
- **Never color alone**: marks change shape (filled check, outlined cross), cards carry words as well as color, and calendar marks come with words on the day.
- **Plain words**: calendar words in Simple, abbreviations explained under quotes, and times that follow the iPhone's 12- or 24-hour setting.
- **Reduce Motion** is respected on Simple screens.
- Keyboard **Next** and **Done** buttons above the number pad in forms.

---

## 19. Settings, app lock and backup

Settings (a sheet in Classic, a page list in Simple) covers:

- **Look**: Automatic, Classic or Simple, plus the five themes.
- **Reminders**: dose and visit reminders, the daily check-in time, **Ask me on stop days**, **Add my plan to Calendar**, **Add To-Dos to Reminders**.
- **How Papers Are Read**: the three steps, downloaded models (with sizes and a download progress bar), Your Mac, and cloud keys.
- **Privacy**: **Names to Hide**, the state of each permission (tap one to change it in iOS Settings), **Lock with Face ID**, whether photos are sent, and **Show my steps on Today**.
- **Papers**: every paper, with open and delete.
- **Backup and Restore.**
- **Delete All Data** ("This removes your plan, papers, dose log and chat from this iPhone. It can't be undone.") and **Clear chat**.
- **Demo mode** and **About**.

### App lock

App lock is off by default. When on, Remedy asks for Face ID (or the passcode as a backup) when it opens, and covers the screen in the app switcher. Turning it on first needs a successful Face ID or passcode, so nobody locks themselves out. If the phone's passcode is later removed, the lock opens instead of trapping the patient.

### Backup and restore

A backup is one file ("Remedy backup 2026-11-15.remedybackup") holding the plan, papers, doses, check-ins and photos, locked with a password of at least 8 characters. It uses AES-GCM encryption with a key made from the password by PBKDF2-SHA256 at 600,000 rounds. "Remedy can't get it back if you forget it." The patient keeps the file in Files or iCloud Drive.

**Restore** takes three steps: choose the file, type the password, then check what's inside (plan name, backup date, and counts of medicines, papers, doses, check-ins and photos). "Nothing on this phone changes until you say yes." A wrong password, a damaged file, or a backup from a newer version each gets its own plain message.

### Where data lives

Pages, the plan, photos, check-ins and chat stay on the iPhone and are not synced. Saved names, API keys and the MyChart sign-in live in the Keychain. Health, Calendar, Reminders, notifications, camera and contacts are asked for only when a feature needs them.

---

## 20. Demo mode

Demo mode lets anyone, including hospital partners, try Remedy with made-up patients. "Everything here is pretend, and your own plan comes back when you leave."

### Sample patients

Sixteen fake plans, grouped:

- **Start here**: **HSS knee replacement** (4 papers, day 4 at home, past days filled in), Surgery in 10 days, Surgery tomorrow, 3 days after surgery, Papers disagree (two doctors give different Eliquis stop days).
- **Which papers**: Before-surgery papers only, After-surgery papers only, Both sets of papers.
- **When the surgery is**: Surgery today, 3 weeks after surgery, Surgery long ago (4 months later).
- **Tricky plans**: No doctor phone numbers, Many stop medicines (six or more), As-needed medicines (pain pills with limits), Appointments today (two visits on the same day), Overdue to-dos.

Loading a sample patient when a real plan exists asks first. The real plan, doses, chat and photos are copied somewhere safe on the phone. **Exit demo mode** brings everything back and removes anything added during the demo.

### The HSS knee replacement demo (Ruth Callahan)

Ruth's plan is built from four realistic sample papers marked SAMPLE:

1. **Internist pre-op visit** (Oct 22): which medicines to stop and when.
2. **Cardiology visit** (Oct 30): "Eliquis 2 days, not 3."
3. **Surgeon pre-op visit** (Nov 2): arrival, fasting and skin prep.
4. **Hospital discharge** (Nov 13): new medicines, rules and visits.

Her right total knee replacement is on Thursday, November 12, 2026 at HSS Lakeside (SAMPLE), with arrival at 6:00 AM. The demo opens on day 4 at home with realistic history already filled in: doses taken a few minutes after their times, pain pills on earlier days, evening check-ins for days 1 to 3 (pain 7, 6, then 5, with notes like "Walked to the kitchen and back 3 times"), finished to-dos, and one missed morning dose today to show the missed-dose question.

Her plan shows red, blue and green paper checks, acetaminophen 2 tablets three times a day (6 AM, 2 PM, 10 PM), oxycodone as needed with a 4-hour gap and a limit of 6 a day, Eliquis restarting after surgery, Walk / PT exercises / Ice goals, home physical therapy and visiting-nurse visits, and a care team with 555-01xx numbers (the surgeon's office at 555-0142, the on-call surgeon at 555-0143, HSS Home Care at 555-0150, and a community pharmacy at 555-0165).

### Pretend today

**Pretend today is** moves the app's clock to any date, so a demo can show the night before, surgery morning, or week two. **Jump to surgery day** and **Back to real today** are one tap. Reminders, the widget and the calendar follow the plan on screen.

### Sample Papers

The **Sample Papers** page holds the four PDFs behind the HSS demo: "Open one to see it, then load HSS knee replacement to see what Remedy made from it." Papers can be shared to Files and then added back through **Add New Papers** to show the adding-papers flow live.

### Read papers with: Your AI or Expected answers

When adding the sample papers in demo mode, the presenter chooses:

- **Your AI**: reads the papers with whatever AI is picked in Settings (for example Claude), exactly as a real patient's papers would be read.
- **Expected answers**: skips the AI and uses the answer key for the sample papers, "so the result is the same every time." This is useful for live demos where the network or timing can't be trusted. It only works in demo mode and only for the sample papers.

### Testing Guide and Check Connections

Demo mode also includes a **Testing Guide**, and **Check Connections**, which tests MyChart and Apple Health with a sample patient record before a demo.

---

## 21. Screenshots

Screenshots of the HSS demo with Ruth Callahan are being captured in three galleries:

- **Before surgery**: see the `docs/app-media/hss-demo/before/` gallery (stop days, papers disagree, ready-for-surgery list).
- **Surgery day**: see the `docs/app-media/hss-demo/surgery-day/` gallery (arrival card, fasting times, the morning in Classic).
- **After surgery**: see the `docs/app-media/hss-demo/after/` gallery (Today on day 4, medicines with as-needed limits, check-in, goals).

Existing captures include the HSS demo set in `docs/app-media/hss-demo/` (Classic Today, Medicines, oxycodone detail, Plan, Ask, Demo mode, Sample Papers and the discharge paper; Simple home, My Day and Medicines), and full tours of each look in `docs/app-media/classic/`, `docs/app-media/simple/` and `docs/app-media/first-run/`.

---

*Remedy helps you read your papers. It doesn't replace your doctor. In an emergency, call 911.*
