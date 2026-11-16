# shared header and footer, run: python3 website/tools/chrome.py
# replaces everything between the chrome markers in each page so all pages stay the same
import re, os
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = {"index.html": "home", "features.html": "features", "technology.html": "technology", "demo.html": "demo", "contact.html": "contact"}
LINKS = [("index.html#how", "How it works", None), ("features.html", "Features", "features"), ("technology.html", "Technology", "technology"), ("demo.html", "Demo", "demo")]

def header(page):
    cur = lambda k: ' aria-current="page"' if k == page else ""
    links = "\n".join(f'      <li><a href="{h}"{cur(k)}>{t}</a></li>' for h, t, k in LINKS)
    menu = "\n".join([f'    <a href="index.html"{cur("home")}>Home</a>'] + [f'    <a href="{h}"{cur(k)}>{t}</a>' for h, t, k in LINKS] + [f'    <a href="contact.html"{cur("contact")}>Contact us</a>'])
    return f'''<!-- chrome:header -->
<a class="skip" href="#main">Skip to content</a>
<div class="nav-shell">
  <nav class="nav" aria-label="Main">
    <a class="brand" href="index.html"><img src="img/icon-180.png" alt="" width="44" height="44">Remedy</a>
    <ul class="nav-links">
{links}
    </ul>
    <div class="nav-actions">
      <a class="btn btn-teal" href="contact.html"{cur("contact")}>Contact us</a>
      <button class="menu-btn" aria-expanded="false" aria-controls="menu" aria-label="Menu">
        <svg width="20" height="14" viewBox="0 0 20 14" aria-hidden="true"><path d="M1 1h18M1 7h18M1 13h18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
      </button>
    </div>
  </nav>
  <div class="menu-panel" id="menu">
{menu}
  </div>
</div>
<!-- /chrome:header -->'''

FOOTER = '''<!-- chrome:footer -->
<footer>
  <div class="wrap">
    <div class="foot">
      <div>
        <a class="brand" href="index.html"><img src="img/icon-180.png" alt="" width="32" height="32">Remedy</a>
        <p>Surgery papers, turned into a plan for each day. Built by Dorron Hoffman and Nikhil Shah in Bergen County, New Jersey.</p>
      </div>
      <div>
        <h4>The app</h4>
        <ul><li><a href="index.html#how">How it works</a></li><li><a href="features.html">Features</a></li><li><a href="technology.html">Technology</a></li></ul>
      </div>
      <div>
        <h4>Work with us</h4>
        <ul><li><a href="demo.html">Demo library</a></li><li><a href="contact.html">Contact us</a></li><li><a href="contact.html?reason=Clinical%20pilot%20or%20trial">Pilots and trials</a></li></ul>
      </div>
    </div>
    <p class="foot-legal">Remedy helps patients read their own papers. It does not replace their doctor, is not a medical device, and has not been clinically validated. Every patient, paper and phone number on this site is made up.</p>
  </div>
</footer>
<script src="site.js" defer></script>
<!-- /chrome:footer -->'''

for f, page in PAGES.items():
    p = os.path.join(HERE, f)
    if not os.path.exists(p): continue
    s = open(p).read()
    s = re.sub(r"<!-- chrome:header -->.*?<!-- /chrome:header -->", lambda m: header(page), s, flags=re.S)
    s = re.sub(r"<!-- chrome:footer -->.*?<!-- /chrome:footer -->", lambda m: FOOTER, s, flags=re.S)
    open(p, "w").write(s)
    print("updated", f)
