//
//  DianeDrafts.swift
//  Remedy
//
//  DEMO ONLY the answer for the demo video's fake patient Diane Morales
//  typed from her papers (DemoVideo/media 07 and 09) with every quote word for word
//  used only by FakePlanReader (-demoFakeAI YES) when the scanned pages are hers
//

import Foundation

// the fake ai answer for the demo video's patient
enum DianeDrafts {

    // MARK: - Before surgery (paper 07)

    static func beforeSurgery() -> DraftPlan {
        var draft = DraftPlan(procedure: "Knee replacement", paper: .beforeSurgery)
        draft.isSample = true
        let sevenDays = "Seven (7) days before your surgery, do not take:"
        let fourDays = "Four (4) days before your surgery, do not take (these cause blood thinning):"
        let okToTake = "OK to take - keep taking these every day, including the morning of surgery:"
        draft.medicines = [
            DraftMedicine(name: "Fish Oil", alsoKnownAs: ["fish oil", "omega-3"], action: .stop, startDay: -7,
                          quote: "\(sevenDays) Fish Oil", quotePage: 1),
            DraftMedicine(name: "Multivitamin", alsoKnownAs: ["multivitamin", "vitamins"], action: .stop, startDay: -7,
                          quote: "\(sevenDays) Multivitamin", quotePage: 1),
            DraftMedicine(name: "Meloxicam", alsoKnownAs: ["mobic", "meloxicam"], action: .stop, startDay: -4,
                          reason: "These cause blood thinning.", quote: "\(fourDays) Meloxicam (Mobic)", quotePage: 1),
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .stop, startDay: -4,
                          reason: "These cause blood thinning.", quote: "\(fourDays) Advil or Motrin (ibuprofen)", quotePage: 1),
            DraftMedicine(name: "Metformin", alsoKnownAs: ["metformin"], action: .stop, startDay: -1, endDay: 0,
                          quote: "The day before surgery and the morning of surgery, do not take: Metformin", quotePage: 1),
            DraftMedicine(name: "Lisinopril", alsoKnownAs: ["lisinopril"], action: .stop, startDay: 0, endDay: 0,
                          quote: "The morning of surgery, do not take: Lisinopril", quotePage: 1),
            DraftMedicine(name: "Aspirin 81 mg", alsoKnownAs: ["baby aspirin", "aspirin"], action: .okToTake,
                          strength: "81 mg", quote: "\(okToTake) Baby aspirin 81 mg", quotePage: 1),
            DraftMedicine(name: "Atorvastatin", alsoKnownAs: ["lipitor", "atorvastatin"], action: .okToTake,
                          quote: "\(okToTake) Atorvastatin", quotePage: 1),
            DraftMedicine(name: "Omeprazole", alsoKnownAs: ["prilosec", "omeprazole"], action: .okToTake,
                          exception: "Take with a sip of water the morning of surgery.",
                          quote: "Omeprazole - take with a sip of water the morning of surgery", quotePage: 1),
            DraftMedicine(name: "Acetaminophen", alsoKnownAs: ["tylenol", "acetaminophen"], action: .okToTake, endDay: -1,
                          onlyIf: "You need something for pain",
                          quote: "Tylenol (acetaminophen) is OK to take before surgery if you need something for pain.", quotePage: 1),
        ]
        draft.rules = [
            DraftRule(title: "Nothing to eat after midnight", isAllowed: false, condition: "The night before surgery",
                      startDay: -1, endDay: 0,
                      quote: "Eating: Nothing to eat after midnight the night before surgery.", quotePage: 2),
            DraftRule(title: "Clear liquids until 2 hours before you arrive", isAllowed: true, startDay: 0, endDay: 0,
                      quote: "You may drink clear liquids (water, apple juice) until 2 hours before your arrival time.", quotePage: 2),
            DraftRule(title: "Don\u{2019}t drive yourself home", isAllowed: false, startDay: 0, endDay: 0,
                      quote: "Driving: You may not drive yourself home. An adult must drive you home after surgery.", quotePage: 2),
        ]
        draft.tasks = [
            DraftTask(title: "Shower with Hibiclens the night before and the morning of surgery", dueDay: -1,
                      quote: "Washing: Shower with Hibiclens (chlorhexidine 4%) the night before and the morning of surgery.", quotePage: 2),
            DraftTask(title: "Answer the pre-surgical phone call (2 to 6 PM) for your arrival time", dueDay: -1,
                      quote: "Pre-Surgical Phone Call The day before surgery, between 2:00 PM and 6:00 PM. A nurse will call with your arrival time.", quotePage: 2),
            DraftTask(title: "Bring your list of medicines and your walker to the hospital", dueDay: 0,
                      quote: "Bring your list of medicines and your walker to the hospital.", quotePage: 2),
            DraftTask(title: "Post-op visit with Thomas Adebayo-Kerr (the office will call you)", dueDay: 14,
                      quote: "Post-Op Visit with Thomas Adebayo-Kerr 2 weeks after surgery. Our office will call you to schedule.", quotePage: 2),
        ]
        draft.contacts = [
            DraftContact(name: "HSS Pre-Surgical Screening", detail: "Your arrival time", phone: "2125550177"),
            DraftContact(name: "Surgeon\u{2019}s office (HSS Paramus)", detail: "Questions about your surgery", phone: "2015550151"),
        ]
        return draft
    }

    // MARK: - After surgery (paper 09)

    static func afterSurgery() -> DraftPlan {
        var draft = DraftPlan(procedure: "Right total knee replacement", paper: .afterSurgery)
        draft.isSample = true
        let restart = "Restart the day after surgery. Take it as you did before."
        let doNotTake = "Meloxicam (Mobic) and Ibuprofen (Advil, Motrin): do NOT take for 4 weeks after surgery while you are on aspirin."
        draft.medicines = [
            DraftMedicine(name: "Acetaminophen", alsoKnownAs: ["tylenol", "acetaminophen"], action: .take, startDay: 0, endDay: 14,
                          strength: "500 mg", amount: "2 tablets", timesOfDay: [0, 480, 960],
                          quote: "Take 2 tablets (1,000 mg total) every 8 hours: 8 AM, 4 PM and 12 AM. Do this for 2 weeks after surgery.", quotePage: 1),
            DraftMedicine(name: "Aspirin 81 mg", alsoKnownAs: ["baby aspirin", "aspirin"], action: .take, startDay: 0, endDay: 28,
                          strength: "81 mg", amount: "1 tablet", timesOfDay: [480, 1200], reason: "This prevents blood clots.",
                          quote: "Take 1 tablet twice a day, in the morning and in the evening, for 4 weeks after surgery. This prevents blood clots.", quotePage: 1),
            DraftMedicine(name: "Oxycodone", alsoKnownAs: ["oxycodone"], action: .takeAsNeeded, startDay: 0, strength: "5 mg", amount: "1 tablet",
                          onlyIf: "Severe pain", minHoursBetween: 4, maxPerDay: 6,
                          quote: "Take 1 tablet every 4 to 6 hours ONLY when needed for severe pain. Do not take more than 6 tablets in one day. Do not drive while taking oxycodone.", quotePage: 1),
            DraftMedicine(name: "Senna", alsoKnownAs: ["senna", "senokot"], action: .take, startDay: 0, strength: "8.6 mg", amount: "1 tablet",
                          timesOfDay: [1260], onlyIf: "While you are taking oxycodone",
                          quote: "Take 1 tablet at bedtime while you are taking oxycodone.", quotePage: 1),
            DraftMedicine(name: "Ondansetron", alsoKnownAs: ["zofran", "ondansetron"], action: .takeAsNeeded, startDay: 0, strength: "4 mg",
                          amount: "1 tablet", onlyIf: "Nausea", minHoursBetween: 8,
                          quote: "Take 1 tablet every 8 hours only when needed for nausea.", quotePage: 1),
            DraftMedicine(name: "Lisinopril", alsoKnownAs: ["lisinopril"], action: .okToTake, startDay: 1, reason: restart,
                          quote: "Lisinopril \(restart)", quotePage: 1),
            DraftMedicine(name: "Metformin", alsoKnownAs: ["metformin"], action: .okToTake, startDay: 1, reason: restart,
                          quote: "Metformin \(restart)", quotePage: 1),
            DraftMedicine(name: "Fish Oil and Multivitamin", alsoKnownAs: ["fish oil", "multivitamin", "vitamins"], isGroup: true,
                          action: .okToTake, startDay: 7, quote: "Fish Oil and Multivitamin You may restart these 1 week after surgery.", quotePage: 1),
            DraftMedicine(name: "Meloxicam", alsoKnownAs: ["mobic", "meloxicam"], action: .stop, startDay: 0, endDay: 28,
                          reason: "While you are on aspirin.", quote: doNotTake, quotePage: 1),
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .stop, startDay: 0, endDay: 28,
                          reason: "While you are on aspirin.", quote: doNotTake, quotePage: 1),
        ]
        draft.rules = [
            DraftRule(title: "No driving", isAllowed: false, condition: "While you take oxycodone", endDay: 28,
                      quote: "Driving: No driving while you take oxycodone, and for at least 4 weeks after surgery.", quotePage: 2),
            DraftRule(title: "Showers (keep the dressing dry)", isAllowed: true, startDay: 3,
                      quote: "Showering: You may shower 3 days after surgery. Keep the dressing dry with a plastic cover.", quotePage: 2),
            DraftRule(title: "No baths, pools or hot tubs", isAllowed: false, endDay: 42,
                      quote: "No baths, pools or hot tubs for 6 weeks after surgery.", quotePage: 2),
            DraftRule(title: "No kneeling", isAllowed: false, quote: "No kneeling.", quotePage: 2),
        ]
        draft.tasks = [
            DraftTask(title: "Pick up your walker before you go home", dueDay: 0,
                      quote: "Pick up your walker before you go home.", quotePage: 2),
            DraftTask(title: "Home physical therapy starts (the PT office will call you)", dueDay: 1,
                      quote: "Physical therapy at home starts the day after surgery. The PT office will call you.", quotePage: 2),
        ]
        let followUp = DateComponents(calendar: Calendar.current, year: 2026, month: 11, day: 17, hour: 10, minute: 30).date ?? Date()
        draft.appointments = [
            DraftAppointment(title: "Follow-Up Visit with Thomas Adebayo-Kerr", date: followUp, doctor: "Thomas Adebayo-Kerr",
                             place: "HSS Paramus", phone: "2015550151",
                             quote: "Follow-Up Visit with Thomas Adebayo-Kerr Tuesday, November 17, 2026 at 10:30 AM", quotePage: 2),
        ]
        draft.goals = [
            DraftGoal(title: "Walk", detail: "With your walker", symbol: "figure.walk", target: 3, startDay: 0,
                      quote: "Walking: Walk with your walker 3 times a day."),
        ]
        draft.contacts = [
            DraftContact(name: "Surgeon\u{2019}s office (HSS Paramus)", detail: "Pain, swelling, warmth or redness in your calf, fever over 101\u{00B0}F",
                         phone: "2015550151"),
            DraftContact(name: "HSS after-hours line", detail: "After hours", phone: "2125550199"),
            DraftContact(name: "Pharmacy", detail: "Questions about your medicines", phone: "2015550164", role: .pharmacy),
        ]
        return draft
    }
}
