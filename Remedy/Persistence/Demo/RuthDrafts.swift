//
//  RuthDrafts.swift
//  Remedy
//
//  DEMO ONLY the answer for the four HSS style sample papers in SamplePapers/demo (fake patient Ruth Callahan)
//  every quote is word for word from the papers and holds no name or phone number so it survives the blackout
//  SamplePapers/demo/EXPECTED.md says what each paper should show in the app
//

import Foundation

// the fake ai answer for the HSS demo papers, one draft per paper
enum RuthDrafts {

    // all four in the order they were printed
    static func all() -> [DraftPlan] { [internist(), cardiology(), surgeon(), discharge()] }

    // the same four with each paper's page text, so Ask and the paper's words work like a real scan
    static func withPages() -> [DraftPlan] {
        zip(all(), DemoPapers.all).map { draft, item in
            var draft = draft
            draft.pages = DemoPapers.pageTexts(item).enumerated().map { DraftPage(pageNumber: $0.offset + 1, redactedText: $0.element) }
            return draft
        }
    }

    // thursday november 12 2026, right total knee replacement
    static let surgery = date(2026, 11, 12)

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        DateComponents(calendar: Calendar.current, year: year, month: month, day: day, hour: hour, minute: minute).date ?? Date()
    }

    // a draft with the paper's giver, doctor and printed date filled in
    private static func base(paper: PaperKind, source: PaperSource, field: PaperField? = nil, doctor: String, printed: Date) -> DraftPlan {
        var draft = DraftPlan(procedure: "Right total knee replacement", paper: paper)
        draft.surgeryDate = surgery
        draft.paperSource = source
        draft.paperField = field
        draft.doctorName = doctor
        draft.hospitalName = "HSS Lakeside (SAMPLE)"
        draft.printedDate = printed
        draft.readBy = "Sample papers (demo)"
        draft.isSample = true
        return draft
    }

    // MARK: - D1 internist pre-op visit, october 22

    static func internist() -> DraftPlan {
        var d = base(paper: .beforeSurgery, source: .primaryCare, doctor: "Dr. Elena Brooks", printed: date(2026, 10, 22, hour: 10, minute: 5))
        let thinning = "These cause blood thinning."
        let morning = "On the morning of your surgery, take the following medications with a sip of water:"
        let nightBefore = "Please take the night before surgery:"
        d.medicines = [
            DraftMedicine(name: "Aspirin 325 mg", alsoKnownAs: ["aspirin"], action: .stop, startDay: -7, strength: "325 mg", reason: thinning,
                          exception: "Baby aspirin 81 mg is permitted if instructed by your doctor.",
                          quote: "Regular Aspirin (325mg) baby aspirin 81mg is permitted if instructed by your doctor.", quotePage: 5),
            DraftMedicine(name: "Multivitamin", alsoKnownAs: ["multivitamin", "vitamins"], action: .stop, startDay: -7, reason: thinning,
                          quote: "Vitamins including Multivitamins", quotePage: 5),
            DraftMedicine(name: "Vitamins and supplements",
                          alsoKnownAs: ["glucosamine", "chondroitin", "fish oil", "gingko", "ginkgo", "garlic", "ginger", "ginseng", "supplements"],
                          isGroup: true, action: .stop, startDay: -7, reason: thinning,
                          quote: "All Vitamins/Supplements including Glucosamine/Chondroitin, Fish Oil, Gingko, Garlic, Ginger or Ginseng", quotePage: 5),
            DraftMedicine(name: "Vitamin D3", alsoKnownAs: ["vitamin d", "vitamin d3"], action: .okToTake,
                          quote: "You can continue your vitamin D, calcium", quotePage: 5),
            DraftMedicine(name: "Calcium", alsoKnownAs: ["calcium"], action: .okToTake,
                          quote: "You can continue your vitamin D, calcium", quotePage: 5),
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .stop, startDay: -4, reason: thinning,
                          quote: "Motrin or Advil (ibuprofen)", quotePage: 5),
            DraftMedicine(name: "Naproxen", alsoKnownAs: ["aleve", "naprosyn", "naproxen"], action: .stop, startDay: -4, reason: thinning,
                          quote: "Aleve or Naprosyn (naproxen)", quotePage: 5),
            DraftMedicine(name: "Meloxicam", alsoKnownAs: ["mobic", "meloxicam"], action: .stop, startDay: -4, reason: thinning,
                          quote: "Discontinue 4 days prior to surgery: Ticagrelor/Brilinta, Non-Steroidal Anti-Inflammatory Drugs (NSAIDs): (including: Ibuprofen (Advil/Motrin), Meloxicam (Mobic)", quotePage: 6),
            DraftMedicine(name: "Acetaminophen", alsoKnownAs: ["tylenol", "acetaminophen"], action: .okToTake, endDay: -1,
                          onlyIf: "You need something for pain",
                          quote: "Tylenol (acetaminophen) is OK to take before surgery if you need something for pain.", quotePage: 5),
            DraftMedicine(name: "Valsartan", alsoKnownAs: ["diovan", "valsartan"], action: .stop, startDay: -1, endDay: -1,
                          quote: "Do not take the following Medication (s) the evening prior to surgery: Valsartan", quotePage: 5),
            DraftMedicine(name: "Levothyroxine", alsoKnownAs: ["synthroid", "levothyroxine"], action: .okToTake, startDay: 0, endDay: 0,
                          strength: "50 mcg", exception: "Take with a sip of water the morning of surgery.", quote: "\(morning) Levothyroxine", quotePage: 5),
            DraftMedicine(name: "Metoprolol", alsoKnownAs: ["toprol", "toprol-xl", "metoprolol", "metoprolol succinate"], action: .okToTake, startDay: 0, endDay: 0,
                          strength: "25 mg", exception: "Take with a sip of water the morning of surgery.", quote: "\(morning) Levothyroxine Metoprolol", quotePage: 5),
            DraftMedicine(name: "Omeprazole", alsoKnownAs: ["prilosec", "omeprazole"], action: .okToTake, startDay: 0, endDay: 0,
                          strength: "20 mg", exception: "Take with a sip of water the morning of surgery.", quote: "\(morning) Levothyroxine Metoprolol Omeprazole", quotePage: 5),
            DraftMedicine(name: "Atorvastatin", alsoKnownAs: ["lipitor", "atorvastatin"], action: .okToTake, startDay: -1, endDay: -1,
                          strength: "20 mg", quote: "\(nightBefore) Atorvastatin", quotePage: 5),
            DraftMedicine(name: "Gabapentin", alsoKnownAs: ["neurontin", "gabapentin"], action: .okToTake, startDay: -1, endDay: -1,
                          strength: "300 mg", quote: "\(nightBefore) Atorvastatin Gabapentin", quotePage: 5),
            // the generic list says 3 days, the heart doctor says 2: the paper check shows both
            // "prior to surgery" holds through surgery day, the discharge paper says when to restart
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .stop, startDay: -3, endDay: 0, strength: "5 mg",
                          quote: "Discontinue 3 days prior to surgery: Xarelto (rivaroxaban), Eliquis (Apixaban)", quotePage: 6),
        ]
        d.tasks = [
            DraftTask(title: "Have your cardiologist fax your heart clearance to Dr. Brooks", dueDay: -7,
                      quote: "Please have your cardiologist send copy of recent testing/clearance to", quotePage: 5),
            DraftTask(title: "Bring your inhalers, eye drops and creams to the hospital", dueDay: 0,
                      quote: "Bring any inhalers, eye drops or creams to the hospital unless otherwise instructed by the HSS pharmacy", quotePage: 5),
        ]
        d.appointments = [
            DraftAppointment(title: "Knee Replacement Webinar", date: date(2026, 11, 5, hour: 13), place: "Online (Zoom)",
                             phone: "5550160", purpose: "Your Pathway to Recovery",
                             quote: "Knee Replacement Webinar Thursday November 5 1:00 PM", quotePage: 2),
            DraftAppointment(title: "Follow Up Visit with Samuel Okafor", date: date(2026, 12, 14, hour: 14, minute: 15), doctor: "Dr. Samuel Okafor",
                             place: "HSS Lakeside Cardiology", phone: "5550131",
                             quote: "Follow Up Visit with Samuel Okafor Monday December 14 2:15 PM", quotePage: 2),
        ]
        d.contacts = [
            DraftContact(name: "Office of Elena Brooks, MD", detail: "Questions about this visit", phone: "5550118"),
        ]
        return d
    }

    // MARK: - D2 cardiology visit, october 30

    static func cardiology() -> DraftPlan {
        var d = base(paper: .beforeSurgery, source: .specialist, field: .heart, doctor: "Dr. Samuel Okafor",
                     printed: date(2026, 10, 30, hour: 15, minute: 42))
        d.medicines = [
            // the last dose is 11/9, so nothing from 11/10 on
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .stop, startDay: -2, endDay: 0, strength: "5 mg",
                          reason: "Take your last dose on 11/9.", exception: "You do not need Lovenox injections.",
                          quote: "Hold Eliquis 2 days before surgery. Take your last dose on 11/9.", quotePage: 1),
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .okToTake, startDay: 1, strength: "5 mg",
                          onlyIf: "Your surgeon says it is safe",
                          quote: "Restart Eliquis 24 hours after surgery if your surgeon says it is safe.", quotePage: 1),
            DraftMedicine(name: "Metoprolol", alsoKnownAs: ["toprol", "toprol-xl", "metoprolol", "metoprolol succinate"], action: .okToTake,
                          strength: "25 mg", exception: "Take it the morning of surgery with a sip of water. Do not stop it suddenly.",
                          quote: "Continue metoprolol every day, including the morning of surgery with a sip of water.", quotePage: 1),
            DraftMedicine(name: "Atorvastatin", alsoKnownAs: ["lipitor", "atorvastatin"], action: .okToTake, strength: "20 mg",
                          quote: "Continue atorvastatin.", quotePage: 1),
        ]
        d.appointments = [
            DraftAppointment(title: "Follow Up Visit with Samuel Okafor", date: date(2026, 12, 14, hour: 14, minute: 15), doctor: "Dr. Samuel Okafor",
                             place: "HSS Lakeside Cardiology", address: "88 River Rd, Suite 300, Lakeside NY 10000", phone: "5550131",
                             bring: ["Arrive 15 minutes early"],
                             quote: "Follow Up Visit with Samuel Okafor Monday December 14 2:15 PM", quotePage: 1),
        ]
        d.contacts = [
            DraftContact(name: "HSS Lakeside Cardiology",
                         detail: "Heart racing or skipping for more than a few minutes, dizzy or lightheaded. Call 911 for chest pain or if you pass out.",
                         phone: "5550131"),
        ]
        return d
    }

    // MARK: - D3 surgeon pre-op visit, november 2

    static func surgeon() -> DraftPlan {
        var d = base(paper: .beforeSurgery, source: .surgeryTeam, doctor: "Dr. Daniel Whitfield", printed: date(2026, 11, 2, hour: 11, minute: 24))
        let nsaids = "Stop all NSAIDs (Advil, Motrin, Aleve, Mobic, Celebrex) 4 days prior to surgery."
        d.medicines = [
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .stop, startDay: -3, endDay: 0, strength: "5 mg",
                          quote: "Stop Eliquis (apixaban) 3 days prior to surgery.", quotePage: 3),
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .stop, startDay: -4, quote: nsaids, quotePage: 3),
            DraftMedicine(name: "Naproxen", alsoKnownAs: ["aleve", "naprosyn", "naproxen"], action: .stop, startDay: -4, quote: nsaids, quotePage: 3),
            DraftMedicine(name: "Meloxicam", alsoKnownAs: ["mobic", "meloxicam"], action: .stop, startDay: -4, quote: nsaids, quotePage: 3),
            DraftMedicine(name: "Celecoxib", alsoKnownAs: ["celebrex", "celecoxib"], action: .stop, startDay: -4, quote: nsaids, quotePage: 3),
        ]
        d.rules = [
            DraftRule(title: "Nothing to eat after midnight", isAllowed: false, condition: "Includes gum, mints and hard candy",
                      startDay: -1, endDay: 0, quote: "Do not eat anything after midnight the night before your surgery.", quotePage: 3),
            DraftRule(title: "Clear liquids until 2 hours before you arrive", isAllowed: true, startDay: 0, endDay: 0,
                      quote: "You may have clear liquids (water, apple juice, Gatorade, black coffee or tea without milk) up until 2 hours before your arrival time.", quotePage: 3),
            DraftRule(title: "Don\u{2019}t shave the knee", isAllowed: false, startDay: -3, endDay: 0,
                      quote: "Do not shave the surgical area for 3 days before surgery.", quotePage: 3),
            DraftRule(title: "No lotion, powder or deodorant after your shower", isAllowed: false, startDay: 0, endDay: 0,
                      quote: "Do not use lotion, powder or deodorant after your shower on the morning of surgery.", quotePage: 3),
            DraftRule(title: "An adult must take you home", isAllowed: false, condition: "Not by taxi, car service or rideshare alone",
                      startDay: 0, endDay: 1, quote: "You must have a responsible adult take you home.", quotePage: 3),
        ]
        d.tasks = [
            DraftTask(title: "Pick up your rolling walker", dueDay: -1,
                      quote: "Please pick up your rolling walker before your surgery date.", quotePage: 3),
            DraftTask(title: "Shower with Hibiclens the night before and the morning of surgery", dueDay: -1,
                      quote: "Shower with Hibiclens (chlorhexidine 4%) soap the night before surgery and the morning of surgery.", quotePage: 3),
            DraftTask(title: "Remove all jewelry, piercings and nail polish", dueDay: 0,
                      quote: "Remove all jewelry, piercings and nail polish.", quotePage: 3),
            DraftTask(title: "Bring your photo ID, insurance card, medicine list and walker", dueDay: 0,
                      quote: "Photo ID and insurance card", quotePage: 3),
        ]
        d.appointments = [
            DraftAppointment(title: "Knee Replacement Webinar", date: date(2026, 11, 5, hour: 13), place: "HSS Education Webinar", phone: "5550127",
                             quote: "Knee Replacement Webinar Thursday November 5 1:00 PM", quotePage: 1),
            DraftAppointment(title: "Total Knee Replacement", date: date(2026, 11, 12, hour: 6), doctor: "Dr. Daniel Whitfield",
                             place: "HSS Lakeside Main OR, Surgical Admitting", address: "400 Harbor St, 4th Floor, Lakeside NY 10000",
                             phone: "5550142", bring: ["Photo ID and insurance card", "Your medicine list", "Your rolling walker", "Inhalers and eye drops"],
                             quote: "Please arrive at 6:00 AM at the HSS Lakeside Main OR", quotePage: 3),
            DraftAppointment(title: "Post Op Visit with Daniel Whitfield", date: date(2026, 12, 1, hour: 10, minute: 30), doctor: "Dr. Daniel Whitfield",
                             place: "HSS Lakeside Orthopedic Surgery", address: "400 Harbor St, 2nd Floor, Lakeside NY 10000", phone: "5550142",
                             quote: "Post Op Visit with Daniel Whitfield Tuesday December 1 10:30 AM", quotePage: 1),
        ]
        d.goals = [
            DraftGoal(title: "Exercises before surgery", detail: "Ankle pumps, quad sets, leg raises, heel slides, short arc quads. 10 each.",
                      symbol: "figure.strengthtraining.functional", target: 2, startDay: -10, endDay: -1,
                      quote: "Doing these exercises before surgery will help you recover. Do each exercise 10 times, 2 times a day."),
        ]
        d.contacts = [
            DraftContact(name: "Office of Daniel Whitfield, MD",
                         detail: "Before surgery: a fever, cold or infection, a cut or rash on your leg, dental work or a new medicine", phone: "5550142"),
            DraftContact(name: "Orthopedic surgeon on call", detail: "After hours", phone: "5550143"),
        ]
        return d
    }

    // MARK: - D4 hospital discharge, november 13

    // the scheduled pain pill, used to know a plan came from these papers
    static let acetaminophenQuote = "Take 2 tablets (1,000 mg total) by mouth every 8 (eight) hours."

    static func discharge() -> DraftPlan {
        var d = base(paper: .afterSurgery, source: .surgeryTeam, doctor: "Dr. Daniel Whitfield", printed: date(2026, 11, 13, hour: 12, minute: 41))
        let starts = "Start taking on: November 14, 2026"
        d.medicines = [
            // start
            DraftMedicine(name: "Acetaminophen", alsoKnownAs: ["tylenol", "acetaminophen"], action: .take, startDay: 1, strength: "500 mg",
                          amount: "2 tablets", timesOfDay: [360, 840, 1320], minHoursBetween: 8,
                          lastGivenText: "Last time this was given: 1,000 mg on November 13, 2026 at 6:02 AM",
                          quote: acetaminophenQuote, quotePage: 2),
            DraftMedicine(name: "Ondansetron", alsoKnownAs: ["zofran", "zofran-odt", "ondansetron"], action: .takeAsNeeded, startDay: 1,
                          strength: "4 mg", amount: "1 tablet", onlyIf: "Nausea or vomiting", minHoursBetween: 8,
                          lastGivenText: "Last time this was given: 4 mg on November 12, 2026 at 9:15 PM",
                          quote: "Take 1 tablet (4 mg total) by mouth every 8 (eight) hours as needed for nausea or vomiting.", quotePage: 2),
            DraftMedicine(name: "Oxycodone", alsoKnownAs: ["roxicodone", "oxycodone"], action: .takeAsNeeded, startDay: 1,
                          strength: "5 mg", amount: "1 tablet", onlyIf: "Severe pain (7-10)", minHoursBetween: 4, maxPerDay: 6,
                          lastGivenText: "Last time this was given: 5 mg on November 13, 2026 at 11:40 AM",
                          quote: "Take 1 tablet (5 mg total) by mouth every 4 (four) hours as needed for severe pain (7-10). Max Daily Amount: 30 mg", quotePage: 2),
            DraftMedicine(name: "Sennosides", alsoKnownAs: ["senokot", "senna", "sennosides"], action: .take, startDay: 1,
                          strength: "8.6 mg", amount: "2 tablets", timesOfDay: [1260], onlyIf: "While taking oxycodone",
                          quote: "Take 2 tablets (17.2 mg total) by mouth nightly while taking oxycodone.", quotePage: 2),
            // change: both restart the day after discharge
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .take, startDay: 2,
                          strength: "5 mg", amount: "1 tablet", timesOfDay: [540, 1260], reason: "Prevents blood clots.",
                          quote: "Take 1 tablet (5 mg total) by mouth 2 (two) times a day. \(starts)", quotePage: 2),
            DraftMedicine(name: "Valsartan", alsoKnownAs: ["diovan", "valsartan"], action: .take, startDay: 2,
                          strength: "80 mg", amount: "1 tablet", timesOfDay: [1140],
                          quote: "Take 1 tablet (80 mg total) by mouth every evening. \(starts)", quotePage: 2),
            // continue
            DraftMedicine(name: "Albuterol inhaler", alsoKnownAs: ["proventil", "proventil hfa", "albuterol"], action: .takeAsNeeded, startDay: 1,
                          strength: "90 mcg", amount: "2 puffs", onlyIf: "Wheezing", minHoursBetween: 4,
                          quote: "Inhale 2 puffs every 4 (four) hours as needed for wheezing.", quotePage: 3),
            DraftMedicine(name: "Atorvastatin", alsoKnownAs: ["lipitor", "atorvastatin"], action: .take, startDay: 1,
                          strength: "20 mg", amount: "1 tablet", timesOfDay: [1260],
                          quote: "Take 1 tablet (20 mg total) by mouth nightly.", quotePage: 3),
            DraftMedicine(name: "Calcium", alsoKnownAs: ["calcium"], action: .okToTake, startDay: 1, quote: "CALCIUM ORAL", quotePage: 3),
            DraftMedicine(name: "Fluticasone nasal spray", alsoKnownAs: ["flonase", "fluticasone"], action: .take, startDay: 1,
                          strength: "50 mcg", amount: "1 spray each nostril", timesOfDay: [480],
                          quote: "1 spray by Each Nostril route daily.", quotePage: 3),
            DraftMedicine(name: "Gabapentin", alsoKnownAs: ["neurontin", "gabapentin"], action: .take, startDay: 1,
                          strength: "300 mg", amount: "1 capsule", timesOfDay: [1260],
                          quote: "Take 1 capsule (300 mg total) by mouth nightly.", quotePage: 3),
            DraftMedicine(name: "Levothyroxine", alsoKnownAs: ["synthroid", "levothyroxine"], action: .take, startDay: 1,
                          strength: "50 mcg", amount: "1 tablet", timesOfDay: [420], foodNote: "Before breakfast",
                          quote: "Take 1 tablet (50 mcg total) by mouth daily before breakfast.", quotePage: 3),
            DraftMedicine(name: "Metoprolol", alsoKnownAs: ["toprol", "toprol-xl", "metoprolol", "metoprolol succinate"], action: .take, startDay: 1,
                          strength: "25 mg", amount: "1 tablet", timesOfDay: [480],
                          quote: "Take 1 tablet (25 mg total) by mouth daily.", quotePage: 3),
            DraftMedicine(name: "Omeprazole", alsoKnownAs: ["prilosec", "omeprazole"], action: .take, startDay: 1,
                          strength: "20 mg", amount: "1 capsule", timesOfDay: [420], foodNote: "Before breakfast",
                          quote: "Take 1 capsule (20 mg total) by mouth daily before breakfast.", quotePage: 3),
            DraftMedicine(name: "Vitamin D3", alsoKnownAs: ["vitamin d", "vitamin d3"], action: .okToTake, startDay: 1,
                          quote: "VITAMIN D3 ORAL", quotePage: 3),
            // stop
            DraftMedicine(name: "Fish oil", alsoKnownAs: ["fish oil", "omega-3"], action: .stop, startDay: 0, quote: "FISH OIL ORAL", quotePage: 3),
            DraftMedicine(name: "Glucosamine-chondroitin", alsoKnownAs: ["glucosamine", "chondroitin"], action: .stop, startDay: 0,
                          quote: "GLUCOSAMINE-CHONDROITIN ORAL", quotePage: 3),
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .stop, startDay: 0,
                          quote: "ibuprofen 200 MG tablet Commonly known as: ADVIL,MOTRIN", quotePage: 3),
            DraftMedicine(name: "Meloxicam", alsoKnownAs: ["mobic", "meloxicam"], action: .stop, startDay: 0,
                          quote: "meloxicam 15 MG tablet Commonly known as: MOBIC", quotePage: 3),
            DraftMedicine(name: "Multivitamin", alsoKnownAs: ["multivitamin", "vitamins"], action: .stop, startDay: 0,
                          quote: "MULTIVITAMIN ORAL", quotePage: 3),
        ]
        d.rules = [
            DraftRule(title: "No driving", isAllowed: false, condition: "And while taking narcotic pain medicine", startDay: 0, endDay: 28,
                      quote: "No driving for 4 weeks and while taking narcotic pain medication.", quotePage: 5),
            DraftRule(title: "No pillow under your knee", isAllowed: false, startDay: 0,
                      quote: "Do not place a pillow under your knee.", quotePage: 5),
            DraftRule(title: "Keep the Aquacel dressing on", isAllowed: true, condition: "If it becomes soaked, call the office", startDay: 0, endDay: 7,
                      quote: "Keep your Aquacel dressing on for 7 days. If it becomes saturated, call the office.", quotePage: 5),
            DraftRule(title: "Showers with the dressing on", isAllowed: true, condition: "Do not soak or scrub the incision", startDay: 3,
                      quote: "You may shower 3 days after surgery with the dressing on. Do not soak or scrub the incision.", quotePage: 5),
            DraftRule(title: "No tub baths, hot tubs or swimming", isAllowed: false, startDay: 0, endDay: 28,
                      quote: "No tub baths, hot tubs or swimming for 4 weeks.", quotePage: 5),
            DraftRule(title: "Wear your TED stockings during the day", isAllowed: true, condition: "You may take them off at night", startDay: 0, endDay: 28,
                      quote: "Wear your TED stockings during the day for 4 weeks. You may remove them at night.", quotePage: 5),
            // warning signs, the office for the first six and 911 for the last three
            DraftRule(title: "Temperature greater than 101.5", isAllowed: false, condition: "Call Dr. Whitfield\u{2019}s office", startDay: 0,
                      quote: "Temperature greater than 101.5", quotePage: 6),
            DraftRule(title: "Increased redness, warmth or drainage from your incision", isAllowed: false, condition: "Call Dr. Whitfield\u{2019}s office", startDay: 0,
                      quote: "Increased redness, warmth or drainage from your incision", quotePage: 6),
            DraftRule(title: "Pain not relieved by your pain medication", isAllowed: false, condition: "Call Dr. Whitfield\u{2019}s office", startDay: 0,
                      quote: "Pain not relieved by your pain medication", quotePage: 6),
            DraftRule(title: "Calf pain, swelling or tenderness", isAllowed: false, condition: "Call Dr. Whitfield\u{2019}s office", startDay: 0,
                      quote: "Calf pain, swelling or tenderness", quotePage: 6),
            DraftRule(title: "Bleeding that does not stop, blood in your urine or black stools", isAllowed: false, condition: "Call Dr. Whitfield\u{2019}s office", startDay: 0,
                      quote: "Bleeding that does not stop, blood in your urine or black stools", quotePage: 6),
            DraftRule(title: "No bowel movement for 3 days", isAllowed: false, condition: "Call Dr. Whitfield\u{2019}s office", startDay: 0,
                      quote: "No bowel movement for 3 days", quotePage: 6),
            DraftRule(title: "Chest pain", isAllowed: false, condition: "Call 911 or go to the nearest emergency room", startDay: 0,
                      quote: "Chest pain", quotePage: 6),
            DraftRule(title: "Shortness of breath or difficulty breathing", isAllowed: false, condition: "Call 911 or go to the nearest emergency room", startDay: 0,
                      quote: "Shortness of breath or difficulty breathing", quotePage: 6),
            DraftRule(title: "Coughing up blood", isAllowed: false, condition: "Call 911 or go to the nearest emergency room", startDay: 0,
                      quote: "Coughing up blood", quotePage: 6),
        ]
        d.tasks = [
            DraftTask(title: "Pick up your new medicines at Lakeside Community Pharmacy", dueDay: 1,
                      quote: "These medications were sent to LAKESIDE COMMUNITY PHARMACY", quotePage: 4),
        ]
        d.appointments = [
            DraftAppointment(title: "Home Physical Therapy Evaluation", date: date(2026, 11, 16, hour: 11), place: "HSS Home Care", phone: "5550150",
                             quote: "Home Physical Therapy Evaluation Monday November 16 11:00 AM", quotePage: 1),
            DraftAppointment(title: "Visiting Nurse - Staple Removal", date: date(2026, 11, 24, hour: 9), place: "HSS Home Care", phone: "5550150",
                             quote: "Visiting Nurse - Staple Removal Tuesday November 24 9:00 AM", quotePage: 1),
            DraftAppointment(title: "Post Op Visit with Daniel Whitfield", date: date(2026, 12, 1, hour: 10, minute: 30), doctor: "Dr. Daniel Whitfield",
                             place: "HSS Lakeside Orthopedic Surgery", address: "400 Harbor St, 2nd Floor, Lakeside NY 10000", phone: "5550142",
                             quote: "Post Op Visit with Daniel Whitfield Tuesday December 1 10:30 AM", quotePage: 1),
            DraftAppointment(title: "Follow Up Visit with Samuel Okafor", date: date(2026, 12, 14, hour: 14, minute: 15), doctor: "Dr. Samuel Okafor",
                             place: "HSS Lakeside Cardiology", phone: "5550131",
                             quote: "Follow Up Visit with Samuel Okafor Monday December 14 2:15 PM", quotePage: 1),
        ]
        d.goals = [
            DraftGoal(title: "Walk", detail: "With your walker, a little farther each day", symbol: "figure.walk", target: 3, startDay: 1,
                      quote: "Walk several times a day. Increase your distance each day as tolerated."),
            DraftGoal(title: "Physical therapy exercises", detail: "The exercises your therapist taught you", symbol: "figure.strengthtraining.functional",
                      target: 3, startDay: 1, quote: "Continue the exercises taught to you by physical therapy 3 times a day."),
            DraftGoal(title: "Ice the knee", detail: "20 minutes, and after exercise", symbol: "snowflake", target: 4, startDay: 1,
                      quote: "Ice the knee for 20 minutes 3-4 times per day and after exercise."),
        ]
        d.contacts = [
            DraftContact(name: "Office of Daniel Whitfield, MD",
                         detail: "Fever over 101.5, redness, warmth or drainage from the incision, pain the medicine doesn\u{2019}t help, calf pain or swelling, bleeding that won\u{2019}t stop, blood in urine or black stools, no bowel movement for 3 days",
                         phone: "5550142"),
            DraftContact(name: "Orthopedic surgeon on call", detail: "After 5 PM and on weekends", phone: "5550143"),
            DraftContact(name: "HSS Home Care", detail: "Physical therapy and the visiting nurse", phone: "5550150"),
            DraftContact(name: "Lakeside Community Pharmacy", detail: "Your new medicines", phone: "5550165", role: .pharmacy),
        ]
        return d
    }
}
