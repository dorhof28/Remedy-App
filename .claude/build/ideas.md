# Feature ideas

Helpers suggest these while building. The lead shows them at the end of each phase, and builds one only when Dorron says so.

Idea: sample phone numbers in SamplePlan.swift (5552014480 etc.) don't follow the 555-01xx rule in CLAUDE.md (phase 0)
Idea: show the Paper's source and printed date on each item's detail card (phase 0)
Idea: banner can't tell a real scan from sample data in demo mode, needs a sample marker on CarePlan (phase 0)
Idea: add a harder text reader check with a rotated or photographed page (phase 1)
Idea: harsher text reader variants (rotation over 15 degrees, heavy blur, real phone photos) to tell old and new readers apart (phase 1)
Idea: when part of a page is skipped, show which page it was on the confirm screen (phase 1)
Idea (maybe later): AI model help reading hard pages in part 1 (photos, handwriting), only for pages the phone reads poorly; skipped for now because Vision tied the old reader on all tests (phase 1)
Idea: hide a whole line with one tap, and show the blacked-out photo on the check screen (phase 1)
Cleanup for Dorron to do by hand later: delete Remedy/Core/NameFinder.swift (unused) and RemedyTests/TempMeasure.swift (blank); then MedicalWords.medicineWords(in:) is unused and can go (phase 1)
Idea: OpenAI-compatible server address and model name sit in UserDefaults until 1.6 presets (not secrets, fine) (phase 1)
Idea: show found date next to each paper's source line in the plan so the person sees which paper wins (phase 1)
Todo: RemedyUITests/DemoTour.swift S1 and S6 need a tap on the new confirm screen's Next before Check each item (phase 1)
Idea: key entry and Send text only switch are only in Classic More settings; Simple has no key entry (phase 1)
Idea: Test connection button for compatible presets; show whether typed model supports vision (phase 1)
Check: default model names came from third-party pages (gpt-5-mini, openrouter/free picks a random model, llama-4-scout, mistral-small-latest, llama3.2-vision); verify against provider docs, consider a fixed OpenRouter default (phase 1)
Cleanup for Dorron: delete RemedyUITests/TmpLook.swift (emptied to one comment) (phase 1)
Idea: dedicated Simple screens (one question each) for Which papers? and How are you adding this? (phase 1)
Idea: LenaRecord.swift duplicates SamplePapers/records/lena-record.json, edit both if it changes; Connection check has no Simple version (phase 2)
Idea: treat a line mentioning a group word (blood thinners such as aspirin) as generic even if it names fewer than 3 medicines; link PaperCheckNote to the plan so notes go with it (phase 2)
Idea: link each CareContact to the Paper it came from so the Call button goes to the right office (phase 2)
Idea: add -demoTab launch option so the Simulator opens Medicines or the sheet without taps (phase 2)
Idea: Call care team button under Not mentioned in What changed (phase 2)
Idea: move the doctor-matched contact lookup from PaperCheckViewModel to Core so the ask-by notification and the Call button name the same office (phase 2)
Idea: guard the on-device Explain text with a rule (reject any number or drug name not in the quotes); add a circle demo patient or -demoTab so the circle card and sheet can be screenshot (phase 2)
Idea: Preview my first week could also show one-day tasks
Idea: photo compare screen with a slider overlay for the same spot across two dates
Idea: add lastGivenText to SamplePatients.b4() for the demo, and show the hospital time on the confirm screen before saving
Idea: re-sync the calendar from RemindersRefresher whenever the plan changes
Idea: let the Everything page grow past two pages for big plans
Idea: let the patient change a stop-day answer after saving it
Idea: add a one-line last check-in summary to the family sheet
Idea: countdown timer for goals with seconds, and importer reads reps/sets/times a day from papers
Idea: save readBy on CarePlan or Paper so mistake reports on saved items name the reader
Idea: expand beyond surgery (optional surgery date, plan type: procedure or illness or long-term condition, Today/Home without countdown). Not planned in phases 0-5; decide after phase 5
Idea: push or scheduled updates so the Live Activity countdown advances while the app is closed
Idea: nudge when the Medical ID text is out of date after the medicine list changes
Idea: add 'Restore from a backup' to the Welcome screen (needed for the new phone case)
