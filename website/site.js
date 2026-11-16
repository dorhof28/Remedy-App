// small helpers shared by every page, no libraries

const CONTACT_EMAIL = "dorron.hoffman@icloud.com";
const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];

// nav gets tighter once the page scrolls
const onScroll = () => document.body.classList.toggle("scrolled", window.scrollY > 24);
window.addEventListener("scroll", onScroll, { passive: true });
onScroll();

// mobile menu open and close
const menuBtn = $(".menu-btn");
const menuPanel = $(".menu-panel");
if (menuBtn && menuPanel) {
  const setMenu = (open) => { menuBtn.setAttribute("aria-expanded", String(open)); menuPanel.dataset.open = String(open); };
  menuBtn.addEventListener("click", () => setMenu(menuBtn.getAttribute("aria-expanded") !== "true"));
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && menuPanel.dataset.open === "true") { setMenu(false); menuBtn.focus(); } });
}

// reveal blocks as they scroll into view
const seen = new IntersectionObserver((entries) => {
  entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("in"); seen.unobserve(e.target); } });
}, { threshold: 0.15, rootMargin: "0px 0px -40px 0px" });
$$("[data-reveal], .steps, .flow, .redact, [data-count]").forEach((el) => seen.observe(el));

// numbers count up once
const counter = new IntersectionObserver((entries) => {
  entries.forEach((e) => {
    if (!e.isIntersecting) return;
    counter.unobserve(e.target);
    const el = e.target, to = Number(el.dataset.count), suffix = el.dataset.suffix || "";
    if (calm) { el.textContent = to + suffix; return; }
    const start = performance.now(), ms = 1200;
    const tick = (t) => {
      const k = Math.min(1, (t - start) / ms), eased = 1 - Math.pow(1 - k, 3);
      el.textContent = Math.round(to * eased) + suffix;
      if (k < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}, { threshold: 0.6 });
$$("[data-count]").forEach((el) => counter.observe(el));

// swap which screenshot shows inside a phone
function showScreen(phone, index) {
  const imgs = $$("img.swap", phone);
  imgs.forEach((img, i) => {
    const was = img.classList.contains("on");
    img.classList.toggle("on", i === index);
    img.classList.toggle("was", was && i !== index);
    if (i === index && img.loading === "lazy") img.loading = "eager";
  });
}

// home page tour, moves on by itself until someone picks a screen
const tour = $(".tour");
if (tour) {
  const items = $$(".tour-item", tour);
  const phone = $(".tour .iphone", tour);
  const cap = $(".tour-cap", tour);
  let current = 0, timer = null, visible = false;
  const dur = 6000;
  tour.style.setProperty("--dur", dur + "ms");
  const select = (i, user) => {
    current = (i + items.length) % items.length;
    items.forEach((b, j) => { b.setAttribute("aria-selected", String(j === current)); b.classList.remove("timing"); b.tabIndex = j === current ? 0 : -1; });
    showScreen(phone, current);
    if (cap) cap.textContent = items[current].dataset.cap || "";
    clearTimeout(timer);
    if (user || calm) return stop();
    void items[current].offsetWidth;
    items[current].classList.add("timing");
    if (visible) timer = setTimeout(() => select(current + 1), dur);
  };
  const stop = () => { clearTimeout(timer); timer = null; tour.classList.add("paused"); items.forEach((b) => b.classList.remove("timing")); };
  items.forEach((b, i) => {
    b.addEventListener("click", () => select(i, true));
    b.addEventListener("keydown", (e) => {
      if (e.key === "ArrowDown" || e.key === "ArrowRight") { e.preventDefault(); select(current + 1, true); items[current].focus(); }
      if (e.key === "ArrowUp" || e.key === "ArrowLeft") { e.preventDefault(); select(current - 1, true); items[current].focus(); }
    });
  });
  new IntersectionObserver(([e]) => {
    visible = e.isIntersecting;
    if (visible && !tour.classList.contains("paused")) select(current);
    else clearTimeout(timer);
  }, { threshold: 0.4 }).observe(tour);
  select(0);
}

// classic or simple screenshots on the features page
const looks = $$("[data-set-look]");
const setLook = (look) => {
  document.body.dataset.look = look;
  looks.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.setLook === look)));
  const sticky = $(".story-phone .iphone");
  if (sticky) $$(".fstep.on").forEach((s) => syncStory(s));
  try { localStorage.setItem("remedy-look", look); } catch (e) {}
};
looks.forEach((b) => b.addEventListener("click", () => setLook(b.dataset.setLook)));
try { const saved = localStorage.getItem("remedy-look"); if (saved && looks.length) setLook(saved); } catch (e) {}

// features page: the sticky phone follows the step in view
const storyPhone = $(".story-phone .iphone");
const storyWhere = $(".story-phone .where");
function syncStory(step) {
  if (!storyPhone) return;
  const look = document.body.dataset.look === "simple" ? "simple" : "classic";
  const id = step.dataset[look] || step.dataset.classic;
  const img = $(`img[data-id="${id}"]`, storyPhone);
  if (img) showScreen(storyPhone, $$("img.swap", storyPhone).indexOf(img));
  if (storyWhere) storyWhere.textContent = step.dataset.where || "";
  $$(".chapters a").forEach((a) => a.classList.toggle("on", a.getAttribute("href") === "#" + step.closest(".chapter").id));
}
const steps = $$(".fstep");
if (steps.length) {
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      steps.forEach((s) => s.classList.toggle("on", s === e.target));
      syncStory(e.target);
    });
  }, { rootMargin: "-45% 0px -45% 0px" });
  steps.forEach((s) => io.observe(s));
  steps[0].classList.add("on");
  syncStory(steps[0]);
}

// technology: the paper check, same order as Core/NewerPaperRule
const sim = $("#sim");
if (sim) {
  const state = { agree: "no", dated: "yes", group: "no", sameDay: "no", team: "yes", month: "no" };
  const out = $("#sim .verdict");
  const decide = () => {
    if (state.agree === "yes") return ["green", "Green: the papers agree", "Shown as one row. Nothing to do."];
    if (state.dated === "no") return ["red", "Red: Remedy doesn't pick", "One paper has no printed date."];
    if (state.group === "yes") return ["red", "Red: Remedy doesn't pick", "A line about a group like NSAIDs never beats a line that names the medicine."];
    if (state.sameDay === "yes") return ["red", "Red: Remedy doesn't pick", "Both were printed the same day, so neither is newer."];
    if (state.team === "yes") return ["blue", "Blue: the newer paper wins", "It comes from the surgery team. It wins only for the days it covers."];
    if (state.month === "yes") return ["blue", "Blue: the newer paper wins", "It was printed a calendar month or more after the other."];
    return ["red", "Red: Remedy doesn't pick", "Different doctors, close together. Call the office."];
  };
  const render = () => {
    const [tone, title, why] = decide();
    out.className = "verdict " + tone;
    out.innerHTML = `<b>${title}</b><span>${why}</span>`;
    if (!calm) { out.classList.remove("pulse"); void out.offsetWidth; out.classList.add("pulse"); }
    $$("[data-q]", sim).forEach((q) => { q.hidden = state.agree === "yes" && q.dataset.q !== "agree"; });
  };
  $$("[data-q]", sim).forEach((q) => {
    $$("button", q).forEach((b) => b.addEventListener("click", () => {
      state[q.dataset.q] = b.value;
      $$("button", q).forEach((x) => x.setAttribute("aria-pressed", String(x === b)));
      render();
    }));
  });
  render();
}

// technology: moving the surgery date moves every day in the plan
const slider = $("#surgery-move");
if (slider) {
  const base = new Date(2026, 10, 12);
  const fmt = (d) => d.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
  const draw = () => {
    const shift = Number(slider.value);
    const surgery = new Date(base); surgery.setDate(base.getDate() + shift);
    $("#surgery-out").textContent = fmt(surgery);
    $$(".daylist li").forEach((li) => {
      const d = new Date(surgery); d.setDate(surgery.getDate() + Number(li.dataset.off));
      const el = $(".date", li);
      el.textContent = fmt(d);
      if (!calm) { el.classList.add("flash"); setTimeout(() => el.classList.remove("flash"), 300); }
    });
  };
  slider.addEventListener("input", draw);
  draw();
}

// demo library
if (window.DEMO_DATA && $("#library")) {
  const data = window.DEMO_DATA;
  const grid = $("#shot-grid"), q = $("#q"), moment = $("#moment"), lookSel = $("#look"), count = $("#count");
  const moments = [...new Set(data.screens.map((s) => s.moment))];
  moments.forEach((m) => moment.insertAdjacentHTML("beforeend", `<option>${m}</option>`));
  const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  let list = [];
  const drawShots = () => {
    const words = q.value.toLowerCase().trim().split(/\s+/).filter(Boolean);
    list = data.screens.filter((s) => {
      if (moment.value && s.moment !== moment.value) return false;
      if (lookSel.value && s.look !== lookSel.value) return false;
      const hay = `${s.screen} ${s.caption} ${s.moment} ${s.look} ${s.id}`.toLowerCase();
      return words.every((w) => hay.includes(w));
    });
    count.textContent = `${list.length} of ${data.screens.length}`;
    grid.innerHTML = list.length ? list.map((s, i) => `
      <li class="shot">
        <button class="open" data-i="${i}" aria-label="Open ${esc(s.screen)}">
          <div class="iphone"><div class="screen"><img src="img/shots/${s.id}.jpg" alt="" loading="lazy" width="900" height="1955"></div></div>
        </button>
        <b>${esc(s.screen)}</b>
        <small>${esc(s.caption)}</small>
        <div class="meta"><span class="badge ${s.look.toLowerCase()}">${s.look}</span><span class="badge">${esc(s.moment)}</span>${s.hold ? '<span class="badge hold">Known bug, hold back</span>' : ""}</div>
        <a class="dl" href="demo/screens/${s.id}.png" download>Download PNG</a>
      </li>`).join("") : `<li class="empty">No screens match. Try fewer words.</li>`;
  };
  [q, moment, lookSel].forEach((el) => el.addEventListener("input", drawShots));
  drawShots();

  // lightbox for one screen
  const lb = $("#lightbox");
  let at = 0;
  const openAt = (i) => {
    at = (i + list.length) % list.length;
    const s = list[at];
    $(".lb-inner .screen img", lb).src = `img/shots/${s.id}.jpg`;
    $(".lb-text h3", lb).textContent = s.screen;
    $(".lb-text .lb-cap", lb).textContent = s.caption;
    $(".lb-text .lb-meta", lb).textContent = `${s.moment}, ${s.look} look`;
    $(".lb-dl", lb).href = `demo/screens/${s.id}.png`;
    lb.dataset.open = "true";
    $(".lb-close", lb).focus();
  };
  const close = () => { lb.dataset.open = "false"; };
  grid.addEventListener("click", (e) => { const b = e.target.closest("button.open"); if (b) openAt(Number(b.dataset.i)); });
  $(".lb-close", lb).addEventListener("click", close);
  $(".lb-prev", lb).addEventListener("click", () => openAt(at - 1));
  $(".lb-next", lb).addEventListener("click", () => openAt(at + 1));
  lb.addEventListener("click", (e) => { if (e.target === lb) close(); });
  document.addEventListener("keydown", (e) => {
    if (lb.dataset.open !== "true") return;
    if (e.key === "Escape") close();
    if (e.key === "ArrowRight") openAt(at + 1);
    if (e.key === "ArrowLeft") openAt(at - 1);
  });

  // papers and patients
  $("#paper-grid").innerHTML = data.papers.map((p) => `
    <li class="paper-card">
      <div class="thumb"><img src="img/papers/${p.file}.jpg" alt="First page of the ${esc(p.title)} sample paper" loading="lazy"></div>
      <div class="body"><b>${esc(p.title)}</b><span class="who">${esc(p.who)}, printed ${esc(p.date)}</span><p>${esc(p.about)}</p>
      <div class="btn-row"><a class="btn btn-teal btn-sm" href="demo/papers/${p.file}.pdf" download>Download PDF</a><a class="btn btn-plain btn-sm" href="demo/papers/${p.file}.pdf" target="_blank" rel="noopener">Open</a></div></div>
    </li>`).join("");
  $("#patient-grid").innerHTML = data.scenarios.map((s) => `
    <li class="patient"><span class="grp">${esc(s.group)}</span><b>${esc(s.title)}</b><span>${esc(s.detail)}</span>
    <code><span>-demoScenario ${s.key}</span><button class="copy" data-copy="-demoScenario ${s.key}">Copy</button></code></li>`).join("");

  // tabs and search box stay in step
  const tabs = $$(".tabs button");
  const panels = $$("[data-panel]");
  const showTab = (name) => {
    tabs.forEach((t) => t.setAttribute("aria-selected", String(t.dataset.tab === name)));
    panels.forEach((p) => { p.hidden = p.dataset.panel !== name; });
    $(".toolbar").hidden = name !== "screens";
    try { history.replaceState(null, "", "#" + name); } catch (e) {}
  };
  tabs.forEach((t) => t.addEventListener("click", () => showTab(t.dataset.tab)));
  const fromHash = location.hash.slice(1);
  showTab(["screens", "papers", "patients", "howto"].includes(fromHash) ? fromHash : "screens");
}

// copy buttons
document.addEventListener("click", async (e) => {
  const b = e.target.closest("[data-copy]");
  if (!b) return;
  try { await navigator.clipboard.writeText(b.dataset.copy); b.textContent = "Copied"; } catch (err) { b.textContent = "Select and copy"; }
  setTimeout(() => { b.textContent = "Copy"; }, 1600);
});

// contact form opens the visitor's mail app with the message filled in
const form = $("#contact-form");
if (form) {
  const params = new URLSearchParams(location.search);
  const reason = params.get("reason");
  if (reason) { const r = $(`input[name="reason"][value="${CSS.escape(reason)}"]`, form); if (r) r.checked = true; }
  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const data = new FormData(form);
    const error = $(".form-error", form);
    const name = (data.get("name") || "").trim();
    const email = (data.get("email") || "").trim();
    const message = (data.get("message") || "").trim();
    if (!name || !email || !message) { error.textContent = "Add your name, email and a message, then try again."; return; }
    error.textContent = "";
    const org = (data.get("org") || "").trim();
    const subject = `Remedy: ${data.get("reason") || "Hello"}`;
    const body = [message, "", `${name}${org ? ", " + org : ""}`, email].join("\n");
    window.location.href = `mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
  });
}
