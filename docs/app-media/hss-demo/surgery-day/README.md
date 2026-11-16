# Remedy surgery day screenshots (HSS knee replacement demo)

All data is made up (demo patient Ruth Callahan). iPhone 18 Pro Max simulator, 9:41 status bar, light mode, Classic and Simple looks.

The demo keeps the papers' real dates (surgery Thu Nov 12) and moves the clock. Before each launch: `defaults delete com.dorronhoffman.Remedy demoDayShift`, then `defaults write com.dorronhoffman.Remedy demoPlanDay -int N`. Launch with `-demoScenario hssKnee -demoTime HH:MM`.

- **morning-**: surgery day Thu Nov 12, 5:00 AM. `demoPlanDay 0`, `-demoTime 05:00`.
- **day1-**: day 1 after surgery Fri Nov 13, coming home, 4:00 PM. `demoPlanDay 1`, `-demoTime 16:00`.
- **evening-**: none kept. At 6:00 PM on surgery day the app shows the same screens as 5:00 AM ("Rules this morning", fasting rules), so the shots would mislead.

Add `-appLookMode classic -appLook classic` or `-appLookMode simple -appLook simple`, plus `-skipPermissionPrompts YES`.

| File | Screen | Caption |
|---|---|---|
| morning-classic-01-today.png | Today (top) | On surgery morning, Today opens with the rules that matter right now: nothing to eat, which medicines to skip, and when clear liquids stop. |
| morning-classic-02-today-rules.png | Today (rules, scrolled) | Each rule from the surgery papers shows how long it lasts, like no driving until Dec 10. |
| morning-classic-03-today-todo.png | Today (to-dos) | The morning's to-do list: bring your ID and insurance card, remove jewelry, and catch anything that was missed. |
| morning-classic-04-medicines.png | Medicines | Every medicine sorted into as-needed, every day, stopped and finished, with a count for each. |
| morning-classic-05-metoprolol.png | Medicine detail | Metoprolol is taken the morning of surgery with a sip of water, quoted word for word from the paper. |
| morning-classic-06-plan.png | Plan | The Plan tab shows the surgery itself: 6:00 AM at HSS Lakeside, on Thu, Nov 12, with call, directions and calendar buttons. |
| morning-classic-07-timeline.png | Timeline | A timeline of every stop and start date before and after surgery. |
| morning-classic-08-plan-todos.png | Plan to-dos | All to-dos in one place, with overdue ones marked in orange. |
| morning-classic-09-help.png | Help | One tap to call 911, the surgeon's office or cardiology, plus when to call. |
| morning-simple-01-home.png | Simple home | The Simple look shows one thing to do now in big, plain words. |
| morning-simple-02-home-next.png | Simple home (done) | After tapping the big button, a clear "Marked as put away" with Undo. |
| morning-simple-03-home-after.png | Simple home | Then the next thing: today is your surgery. |
| morning-simple-04-my-day.png | Simple My Day (1 of 11) | My Day walks through today one card at a time. |
| morning-simple-05-my-day-2.png | Simple My Day (2 of 11) | Clear liquids are OK until 2 hours before you arrive. |
| morning-simple-06-my-day-3.png | Simple My Day (3 of 11) | A reminder that an adult must take you home. |
| morning-simple-07-medicines.png | Simple Medicines | A plain list of medicines and what to do with each. |
| morning-simple-08-levothyroxine.png | Simple medicine detail | Synthroid is allowed through surgery day (Thu, Nov 12), with the paper one tap away. |
| day1-classic-01-today.png | Today (top) | Home the day after surgery: the next dose is front and center with a big I Took It button. |
| day1-classic-02-took-it.png | Today (after I Took It) | Tapping I Took It logs the dose with the time and offers Undo, then the next medicine moves up. |
| day1-classic-03-today-later.png | Today (scrolled) | Below the doses: medicines still on hold and the rules for today. |
| day1-classic-04-medicines.png | Medicines | The new discharge medicines, with when each one is next due. |
| day1-classic-05-oxycodone.png | Oxycodone detail | "Can I take it now?" answers plainly: not yet, next one at 6:05 PM, and shows the 30 mg daily limit from the paper. |
| day1-classic-06-acetaminophen.png | Acetaminophen detail | A missed acetaminophen dose, flagged so it can still be logged. |
| day1-classic-07-acetaminophen-taken.png | Acetaminophen (taken) | Logged: the 2:02 PM dose now shows when it was taken. |
| day1-classic-08-dose-log.png | Dose log | The dose log keeps every dose since surgery, and changes are kept and marked. |
| day1-classic-09-plan.png | Plan | The next visit is the home physical therapy evaluation on Monday, Nov 16. |
| day1-classic-10-timeline.png | Timeline | The timeline now marks surgery as done and today as day 1. |
| day1-classic-11-eliquis.png | Eliquis detail | Eliquis restarts Sat, Nov 14, exactly as the discharge paper says, with every paper that mentions it listed below. |
| day1-simple-01-home.png | Simple home | The Simple look asks plainly about a missed dose: did you take the 2:02 PM acetaminophen? |
| day1-simple-02-took-it.png | Simple home (taken) | A clear "Marked as taken" with Undo. |
| day1-simple-03-next.png | Simple home | Next up: a quick check-in on how you feel today. |
| day1-simple-04-my-day.png | Simple My Day (1 of 20) | Day 1, one card at a time. |
| day1-simple-05-my-day-2.png | Simple My Day (2 of 20) | No tub baths, hot tubs or swimming until Dec 10. |
| day1-simple-06-medicines.png | Simple Medicines | Each medicine with its next time, in plain words. |
| day1-simple-07-oxycodone.png | Simple oxycodone | The pain pill shows when it's OK again and how many are left today. |
| day1-simple-08-help.png | Simple Help | Big buttons to call 911, the office or HSS. |

Notes before using publicly (app bugs, not fixed):
- morning-classic-04 and morning-simple-07 show Metoprolol twice.
- day1-classic-11 lists "Before surgery paper" twice.
