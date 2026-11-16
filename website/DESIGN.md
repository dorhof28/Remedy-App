# Remedy website: design plan

## Job of the site

Audience: hospital staff and clinical partners first, patients and families second.
Job: in under a minute, show that Remedy turns a stack of surgery papers into one plan for each day, and that it never guesses on medical questions.

## Tokens (taken from the app's `Theme.swift`, Remedy theme)

| Name | Light | Dark | Use |
|---|---|---|---|
| blush | `#FDF2F5` | `#000000` | page |
| surface | `#FFFFFF` | `#1C1C1E` | panels, nav pill |
| ink | `#000000` | `#FFFFFF` | text |
| ink2 | `#5F5F64` | `#AEAEB2` | second-line text |
| teal | `#158069` | `#2A9D82` | the one filled action |
| tealInk | `#0F6D5A` | `#3DB596` | links, brand text |
| tealSoft | `#E3F1EE` | `#15322B` | quiet tint |
| logo mint / pink | `#7BD6C0` / `#FCC3D5` | same | decoration only, never text |
| red / blue | `#B3261E` / `#1C62C4` | `#FF8E88` / `#8CC2FF` | only to explain the paper check colors |

Type: the system font stack (SF Pro on Apple, Roboto/Segoe elsewhere). This is the app's own face, and it costs zero download.
Headlines copy the iOS large title: heavy weight, tight tracking. One type scale (ratio about 1.25).

## Layout

```
HOME (short: hero + 4 bands)
┌──────────────────────────────────────────────┐
│ (pill nav) [icon] Remedy   How it works  Features  Technology   (Contact us) │
├──────────────────────────────────────────────┤
│ Large title, left            │  4 real SAMPLE papers fan out      │
│ one line of what it does     │  from behind the phone (Today)     │
│ [See how it works] [Contact] │                                     │
├──────────────────────────────────────────────┤
│ Why: three sourced numbers set inside one paragraph of large text  │
├──────────────────────────────────────────────┤
│ How it works: 1 Add papers  2 Check each line  3 Follow the day    │
│ (a real sequence, so numbers are earned; one phone shot each)      │
├──────────────────────────────────────────────┤
│ The paper check: red-card screenshot + 3 color rows                │
├──────────────────────────────────────────────┤
│ Three HSS quotes, large, no cards                                  │
├──────────────────────────────────────────────┤
│ Footer: links, Dorron Hoffman and Nikhil Shah, Bergen County NJ    │
└──────────────────────────────────────────────┘

FEATURES: follows Ruth through her surgery (before, surgery day, coming home,
recovery), then Ask, Help, Simple look, Privacy. Each row is one phone + 2–4 short lines.
A Classic/Simple segmented control swaps the shots (an iOS control, and a real choice in the app).

TECHNOLOGY: the rule (AI reads, rules decide), the layers as a stacked diagram,
the paper check decision path, reader privacy tiers table, frameworks list, testing.

CONTACT: three reasons to write (clinical pilot or trial, hospital partnership, just to talk),
a short form, the two developers.
```

Alignment: left-aligned text everywhere. Max line length about 65 characters.

## Principles

1. The papers are the hero. Real SAMPLE pages from the demo, not drawings.
2. Show the app's screens as they are. No fake UI.
3. One motion moment: the papers fan out on load (CSS only, about 700 ms, off with Reduce Motion). Nothing else moves unless the visitor acts.
4. Every number has a source link.
5. Same voice as the app: plain words, short sentences, no "we're excited".

## Review against generic defaults

- Cream + serif + terracotta: not used. The pink is the app's own page color.
- Card kit: the app uses white cards, so the site keeps them only where the app does (nav pill, panels). Papers have square corners and no radius; phones have device radius; buttons are full pills. Three radii, each with a reason.
- Big-number stat tiles (the generic stats row): replaced by numbers set inside one readable paragraph with footnote sources.
- All-caps eyebrows, middle-dot meta strings, arrows on buttons, monospace labels: none.
- Numbered markers: only on "How it works", which is a true sequence.
- Changed after review: the first draft had a stats row of three tiles and a features grid of icon cards. Both were swapped for the paragraph and the phone rows above, since they read as template.
