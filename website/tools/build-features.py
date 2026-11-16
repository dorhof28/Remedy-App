# builds website/features.html from the step list below, run: python3 website/tools/build-features.py
# then run website/tools/chrome.py to add the header and footer
import os, html
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# chapter id, title, when, steps: (title, text, classic shot, simple shot or None, tag or None)
CHAPTERS = [
  ("before", "Getting ready", "Saturday, Nov 7. Surgery in 5 days.", [
    ("Papers that disagree come first",
     "Ruth's heart doctor says to stop Eliquis 2 days before surgery. Her other papers say 3. Today opens with that warning and tells her who to call.",
     "before-classic-01-today", "before-simple-01-home", "Paper check"),
    ("Both quotes, side by side",
     "Each doctor's exact words and print date. Until the office answers, Remedy says which paper reminders follow, and the card stays red.",
     "before-classic-03-papers-disagree", "before-simple-09-papers-disagree", None),
    ("Every stop and start on one timeline",
     "Stop days, surgery, restarts and visits in date order. Every date counts from surgery, so if surgery moves, the whole plan moves with it.",
     "before-classic-13-timeline", None, None),
  ]),
  ("night", "The night before", "Wednesday, Nov 11, 8 PM.", [
    ("Only tonight's steps",
     "Stop valsartan and take the Hibiclens shower. The Simple look shows just the next step.",
     "before-night-before-classic-01-today", "before-night-before-simple-01-home", None),
    ("Fasting rules with the paper's words",
     "\"Nothing to eat after midnight\" is shown with the line it came from. \"Clear liquids until 2 hours before arrival\" becomes a clock time.",
     "before-night-before-classic-04-fasting-rule", "before-night-before-simple-03-instructions", None),
  ]),
  ("surgery", "Surgery day", "Thursday, Nov 12, 5 AM.", [
    ("What matters this morning",
     "Nothing to eat, which medicines to skip, and when clear liquids stop. On busy days a Live Activity keeps the list on the Lock Screen.",
     "surgery-day-morning-classic-01-today", "surgery-day-morning-simple-01-home", "Live Activity"),
    ("Where to be, and when",
     "Arrival at 6:00 AM at HSS Lakeside, with call, directions and calendar buttons. Simple reminds her that an adult must take her home.",
     "surgery-day-morning-classic-06-plan", "surgery-day-morning-simple-06-my-day-3", None),
  ]),
  ("home", "Coming home", "Friday, Nov 13, 4 PM. Day 1.", [
    ("The next dose, front and center",
     "When the discharge papers say when a medicine was last given, the first dose at home is timed from then.",
     "surgery-day-day1-classic-01-today", "surgery-day-day1-simple-01-home", "Last-given times"),
    ("Restarts on the paper's day",
     "Eliquis restarts Saturday, Nov 14, as the discharge paper says, with every paper that mentions it listed below.",
     "surgery-day-day1-classic-11-eliquis", "surgery-day-day1-simple-06-medicines", None),
    ("Pain pills within the limits",
     "\"Not yet. Next one at 6:05 PM.\" The gap between doses and the daily limit come from the paper.",
     "surgery-day-day1-classic-05-oxycodone", "surgery-day-day1-simple-07-oxycodone", None),
  ]),
  ("recovery", "Recovery", "Monday, Nov 16. Day 4 at home.", [
    ("A missed dose is a question",
     "\"Did you take the 9 AM apixaban?\" Remedy never tells a patient to take an extra dose to catch up. An automated test checks it.",
     "after-classic-03-missed-dose-question", "after-simple-16-home-missed-apixaban", None),
    ("Walks, exercises and ice",
     "Goals from the discharge paper, one tap each. Every goal shows the words it came from.",
     "after-classic-06-goals", None, None),
    ("A daily check-in",
     "Pain from 0 to 10 and the warning signs listed on her own papers. Pain of 8 or more shows Call Surgeon's Office right away.",
     "after-classic-09-pain-8-call-surgeon", "after-simple-19-checkin-pain-call", None),
    ("Pain over time",
     "A chart of each day's score: 7, 6, 5, then 4 today. VoiceOver reads it in words.",
     "after-classic-11-checkin-history", "after-simple-18-checkin-pain", None),
    ("Ask the papers",
     "\"Can I take a bath?\" Not yet, with the quote from page 5. Questions about chest pain or bleeding go straight to a call button. If the papers don't say, Remedy says that.",
     "after-classic-48-ask-bath", "after-simple-13-ask-answer", "Never sent to a cloud AI"),
    ("When to call, and who",
     "Each warning sign from her papers has its own call button. 911 is always one tap away.",
     "after-classic-45-help-when-to-call", "after-simple-10-when-to-call", None),
    ("A copy for family",
     "The full plan, a week, one day with tick boxes, or the medicine list, as a PDF. Her name prints only if she turns it on.",
     "after-classic-29-share-plan", "after-simple-11-share-with-family", None),
  ]),
  ("setup", "Setup and privacy", "Before any of this.", [
    ("Papers in, from anywhere",
     "Scan with the camera, pick photos or PDFs, or import visits and medicines from MyChart and Apple Health.",
     "before-welcome-04-pages", "before-welcome-05-mychart-import", None),
    ("She picks who reads the papers",
     "Reading can stay on the iPhone. If she picks a cloud AI with her own key, names and record numbers are blacked out first and she sees the page before tapping Send.",
     "after-classic-40-ai-reader-choice", "before-welcome-03-reader", None),
  ]),
]

ALSO = [
  ("Widgets", "Next dose and days to surgery on the Home and Lock Screen"),
  ("Siri", "\"What do I take in Remedy?\""),
  ("Calendar and Reminders", "Surgery, stop days, visits and to-dos in a Remedy calendar"),
  ("Read Aloud", "Built into the Simple screens"),
  ("Photos of the incision", "Kept only inside Remedy, shared as a PDF"),
  ("Face ID lock", "Off until the patient turns it on"),
  ("Encrypted backups", "One password-locked file the patient keeps"),
  ("Emergency card", "Words for Medical ID and a wallet-sized PDF"),
  ("Demo mode", "16 sample patients, the patient's own plan set aside"),
]

e = html.escape
def img(shot, cls, alt, lazy=True):
    lazy_attr = ' loading="lazy"' if lazy else ""
    return f'<img class="{cls}" data-id="{shot}" src="img/shots/{shot}.jpg" alt="{e(alt)}" width="900" height="1955"{lazy_attr}>'

def phone(classic, simple, alt):
    simple = simple or classic
    if simple == classic:
        return f'<div class="iphone"><div class="screen">{img(classic, "", alt)}</div></div>'
    return (f'<div class="iphone look-classic"><div class="screen">{img(classic, "", alt)}</div></div>'
            f'<div class="iphone look-simple"><div class="screen">{img(simple, "", alt + ", Simple look")}</div></div>')

steps_html, sticky_imgs, seen = [], [], set()
first = True
for cid, ctitle, when, steps in CHAPTERS:
    block = [f'<section class="chapter" id="{cid}" aria-labelledby="{cid}-h">',
             f'  <div class="chapter-title"><h2 id="{cid}-h">{e(ctitle)}</h2></div>',
             f'  <p class="chapter-when">{e(when)}</p>']
    for title, text, classic, simple, tag in steps:
        for s in (classic, simple):
            if s and s not in seen:
                seen.add(s)
                sticky_imgs.append(img(s, "swap" + (" on" if first else ""), title, lazy=not first))
                first = False
        where = f"{ctitle}: {when.split('.')[0]}"
        data_simple = f' data-simple="{simple}"' if simple else ""
        tagh = f'<span class="tagline">{e(tag)}</span>' if tag else ""
        block.append(f'''  <article class="fstep" data-classic="{classic}"{data_simple} data-where="{e(where)}">
    <h3>{e(title)}</h3>
    <p>{e(text)}</p>
    {tagh}
    <div class="step-phone">{phone(classic, simple, title)}</div>
  </article>''')
    block.append('</section>')
    steps_html.append("\n".join(block))

chapter_links = "".join(f'<li><a href="#{cid}">{e(t)}</a></li>' for cid, t, _, _ in CHAPTERS)
also = "".join(f'<li data-reveal style="--i:{i % 3}"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6L9 17l-5-5"/></svg><div><b>{e(a)}</b><span>{e(b)}</span></div></li>' for i, (a, b) in enumerate(ALSO))

page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Remedy features</title>
<meta name="description" content="What Remedy does before surgery, on surgery day and during recovery, shown with a sample knee replacement patient.">
<meta name="theme-color" content="#FDD3DC" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">
<link rel="icon" href="img/favicon-64.png">
<link rel="apple-touch-icon" href="img/icon-180.png">
<link rel="stylesheet" href="styles.css">
<script>if (!matchMedia("(prefers-reduced-motion: reduce)").matches) document.documentElement.classList.add("motion");</script>
</head>
<body data-look="classic">
<!-- chrome:header -->
<!-- /chrome:header -->

<main id="main">

  <header class="page-head">
    <div class="blob blob-mint" aria-hidden="true"></div>
    <div class="blob blob-pink" aria-hidden="true"></div>
    <div class="wrap">
      <h1>Features</h1>
      <p class="lede">Follow Ruth, a sample patient, from five days before her knee replacement through recovery at home.</p>
      <div class="feature-tools">
        <div class="segmented" role="group" aria-label="Which look to show">
          <button type="button" data-set-look="classic" aria-pressed="true">Classic</button>
          <button type="button" data-set-look="simple" aria-pressed="false">Simple</button>
        </div>
        <p>Classic shows everything on the papers. Simple shows one thing at a time in large type, and turns on by itself at the largest text sizes.</p>
      </div>
    </div>
  </header>

  <nav class="chapters wrap" aria-label="Chapters"><ul>{chapter_links}</ul></nav>

  <div class="wrap story">
    <div class="story-steps">
{chr(10).join(steps_html)}
    </div>
    <div class="story-phone" aria-hidden="true">
      <div class="iphone"><div class="screen">
        {(chr(10) + "        ").join(sticky_imgs)}
      </div></div>
      <p class="where"></p>
    </div>
  </div>

  <section class="band" aria-labelledby="also-h">
    <div class="wrap">
      <div class="head" data-reveal><h2 id="also-h">Also in Remedy</h2></div>
      <ul class="also">{also}</ul>
    </div>
  </section>

  <section aria-label="Contact">
    <div class="wrap">
      <div class="cta" data-reveal="zoom">
        <div>
          <h2>See it live with the sample patient.</h2>
          <p>We'll walk your team through Ruth's four papers and the plan Remedy builds from them.</p>
        </div>
        <div class="btn-row">
          <a class="btn btn-teal" href="contact.html?reason=Live%20demo">Book a walkthrough</a>
          <a class="btn btn-plain" href="demo.html">Demo library</a>
        </div>
      </div>
    </div>
  </section>

</main>

<!-- chrome:footer -->
<!-- /chrome:footer -->
</body>
</html>
'''
open(os.path.join(HERE, "features.html"), "w").write(page)
print("features.html written,", sum(len(c[3]) for c in CHAPTERS), "steps")
