# builds website/demo/data.js from the screenshot readmes, run from the repo root
import json, re, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MEDIA = os.path.join(ROOT, "docs/app-media/hss-demo")
OUT = os.path.join(ROOT, "website/demo/data.js")

# shots with known display bugs, from docs/website/GALLERY.md
HOLD = {"before-classic-05-medicines-stopped", "before-classic-06-eliquis-detail",
        "surgery-day-morning-classic-04-medicines", "surgery-day-morning-simple-07-medicines",
        "before-night-before-simple-02-my-day", "after-classic-31-appointment-detail",
        "after-later-classic-04-staple-removal-visit"}

def moment(stage, name):
    if stage == "before":
        if name.startswith("welcome"): return "First run"
        if name.startswith("night-before"): return "Night before surgery"
        return "5 days before surgery"
    if stage == "surgery-day":
        return "Surgery morning" if name.startswith("morning") else "Home, day 1"
    return "Day 14" if name.startswith("later") else "Day 4 at home"

def look(name):
    if "simple" in name: return "Simple"
    if name.startswith("welcome"): return "Setup"
    return "Classic"

screens = []
for stage in ["before", "surgery-day", "after"]:
    for line in open(os.path.join(MEDIA, stage, "README.md")):
        m = re.match(r"\|\s*([a-z0-9-]+)\.png\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|", line)
        if not m: continue
        name, screen, caption = m.groups()
        sid = f"{stage}-{name}"
        screens.append({"id": sid, "moment": moment(stage, name), "look": look(name),
                        "screen": screen, "caption": caption, "hold": sid in HOLD})

papers = [
    {"file": "D1-internist-preop", "title": "Internist pre-op visit", "who": "Primary care, Dr. Elena Brooks", "date": "Oct 22, 2026", "about": "Which medicines to stop before surgery, and when."},
    {"file": "D2-cardiology-letter", "title": "Cardiology letter", "who": "Heart doctor, Dr. Samuel Okafor", "date": "Oct 30, 2026", "about": "Stop Eliquis 2 days before surgery, not 3. Creates the red paper check."},
    {"file": "D3-surgeon-preop", "title": "Surgeon pre-op visit", "who": "Surgery team, Dr. Daniel Whitfield", "date": "Nov 2, 2026", "about": "Arrival time, fasting and skin prep."},
    {"file": "D4-discharge", "title": "Hospital discharge", "who": "Surgery team, Dr. Daniel Whitfield", "date": "Nov 13, 2026", "about": "New medicines with last-given times, rules, goals and visits."},
]

# demo patients, from DemoScenario.swift
scenarios = [
    ("hssKnee", "Start here", "HSS knee replacement", "4 papers, day 4 at home, past days filled in"),
    ("surgeryIn10Days", "Start here", "Surgery in 10 days", "Full plan, getting ready"),
    ("surgeryTomorrow", "Start here", "Surgery tomorrow", "Full plan, the night before"),
    ("threeDaysAfter", "Start here", "3 days after surgery", "Full plan, early recovery"),
    ("conflictingPapers", "Start here", "Papers disagree", "Two doctors give different Eliquis stop days"),
    ("beforeOnly", "Which papers", "Before-surgery papers only", "Knee replacement, 10 days away"),
    ("afterOnly", "Which papers", "After-surgery papers only", "Knee replacement, 5 days ago"),
    ("bothPapers", "Which papers", "Both sets of papers", "Before and after papers, 2 days after"),
    ("surgeryToday", "When the surgery is", "Surgery today", "Full plan, surgery day"),
    ("threeWeeksAfter", "When the surgery is", "3 weeks after surgery", "Full plan, getting stronger"),
    ("longAgo", "When the surgery is", "Surgery long ago", "Full plan, 4 months later"),
    ("missingDoctorPhone", "Tricky plans", "No doctor phone numbers", "Contacts and visits with no phone"),
    ("manyStopMedicines", "Tricky plans", "Many stop medicines", "Six or more medicines to stop"),
    ("asNeededMedicines", "Tricky plans", "As-needed medicines", "Pain pills with limits, day after surgery"),
    ("appointmentsToday", "Tricky plans", "Appointments today", "Two visits on today's date"),
    ("overdueTodos", "Tricky plans", "Overdue to-dos", "Day 5 with to-dos still open"),
]
scenarios = [{"key": k, "group": g, "title": t, "detail": d} for k, g, t, d in scenarios]

with open(OUT, "w") as f:
    f.write("// made by website/tools/build-demo-data.py, edit the readmes or that script and run it again\n")
    f.write("window.DEMO_DATA = ")
    json.dump({"screens": screens, "papers": papers, "scenarios": scenarios}, f, indent=1)
    f.write(";\n")
print(len(screens), "screens")
