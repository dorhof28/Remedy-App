//
//  SampleDrafts.swift
//  Remedy
//
//  demo only fake ai answer for the sample papers
//

import Foundation

// the fake ai answer for the sample papers, used with -demoFakeAI
enum SampleDrafts {

    // pretend scanned text with fake personal info so the redaction step has something to black out on camera
    static func pageText(for paper: PaperKind) -> String {
        switch paper {
        case .beforeSurgery:
            return """
            AFTER VISIT SUMMARY
            Patient: Jane Sample   MRN: 48213377
            DOB: 03/12/1958
            Directions for Your Medications Preoperatively
            1. Seven (7) days prior to your surgery, do not take the following medications and supplements (these cause blood thinning): Regular Aspirin (325mg) baby aspirin 81mg is permitted if instructed by your doctor. Vitamins including Multivitamins. All Vitamins/Supplements including Glucosamine/Chondroitin, Fish Oil Gingko, Garlic, Ginger or Ginseng.
            2. Four (4) days prior to your joint replacement surgery, do not take the following medications (these cause blood thinning): Motrin or Advil (ibuprofen). Aleve or Naprosyn (naproxen). Any other NSAID.
            3. Tylenol (acetaminophen) is OK to take before surgery if you need something for pain.
            4. Bring any inhalers, eye drops or creams to the hospital unless otherwise instructed by the HSS pharmacy.
            5. Viagra (sildenafil) & Cialis (tadalafil): stop 1 day before surgery.
            """
        case .afterSurgery:
            return """
            DISCHARGE INSTRUCTIONS
            Patient: Jane Sample   MRN: 48213377
            Acetaminophen 1000 mg by mouth every 8 hours for pain.
            Aspirin 81 mg by mouth twice a day for 35 days to prevent blood clots.
            Oxycodone 5 mg every 6 hours as needed for severe pain. Do not drive.
            You may shower 3 days after surgery. Keep the dressing dry.
            Follow up with your surgeon in 2 weeks. Call the office to schedule.
            Begin outpatient physical therapy within one week of surgery.
            """
        }
    }

    // fake ai answer for these papers
    static func draft(for paper: PaperKind, pages: [String]) -> DraftPlan {
        var draft = paper == .beforeSurgery ? beforeSurgery() : afterSurgery()
        // DEMO ONLY the video's photos of Diane Morales's papers (07 and 09) get her own answer
        if isDianesPaper(pages) {
            draft = paper == .beforeSurgery ? DianeDrafts.beforeSurgery() : DianeDrafts.afterSurgery()
        }
        // DEMO ONLY the sample paper sets match by their quotes
        if let patient = SamplePatients.draft(matching: pages) {
            draft = patient
        }
        draft.pages = pages.enumerated().map { DraftPage(pageNumber: $0.offset + 1, redactedText: $0.element) }
        return draft
    }

    // DEMO ONLY her papers name medicines the HSS sample page doesn't
    private static func isDianesPaper(_ pages: [String]) -> Bool {
        let text = pages.joined(separator: " ").lowercased()
        return ["meloxicam", "metformin", "lisinopril", "ondansetron"].contains { text.contains($0) }
    }

    // MARK: - Before surgery (HSS page)

    private static func beforeSurgery() -> DraftPlan {
        var draft = DraftPlan(procedure: "Knee replacement", paper: .beforeSurgery)
        draft.isSample = true
        let thinning = "These cause blood thinning."
        draft.medicines = [
            DraftMedicine(name: "Aspirin 325 mg", alsoKnownAs: ["aspirin", "bayer", "ecotrin"], action: .stop, startDay: -7,
                          reason: thinning, exception: "Baby aspirin 81 mg is permitted if instructed by your doctor.",
                          quote: "Regular Aspirin (325mg) baby aspirin 81mg is permitted if instructed by your doctor.", quotePage: 1),
            DraftMedicine(name: "Vitamins and supplements",
                          alsoKnownAs: ["multivitamin", "vitamins", "glucosamine", "chondroitin", "fish oil", "gingko", "ginkgo", "garlic", "ginger", "ginseng"],
                          isGroup: true, action: .stop, startDay: -7, reason: thinning,
                          quote: "All Vitamins/Supplements including Glucosamine/Chondroitin, Fish Oil Gingko, Garlic, Ginger or Ginseng", quotePage: 1),
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["motrin", "advil", "ibuprofen"], action: .stop, startDay: -4,
                          reason: thinning, quote: "Motrin or Advil (ibuprofen)", quotePage: 1),
            DraftMedicine(name: "Naproxen", alsoKnownAs: ["aleve", "naprosyn", "naproxen"], action: .stop, startDay: -4,
                          reason: thinning, quote: "Aleve or Naprosyn (naproxen)", quotePage: 1),
            DraftMedicine(name: "Any other NSAID", alsoKnownAs: ["nsaid", "celecoxib", "celebrex", "meloxicam", "mobic", "diclofenac", "voltaren"],
                          isGroup: true, action: .stop, startDay: -4, reason: thinning, quote: "Any other NSAID", quotePage: 1),
            DraftMedicine(name: "Acetaminophen", alsoKnownAs: ["tylenol", "acetaminophen", "paracetamol"], action: .okToTake, endDay: -1,
                          onlyIf: "You need something for pain",
                          quote: "Tylenol (acetaminophen) is OK to take before surgery if you need something for pain.", quotePage: 1),
            DraftMedicine(name: "Sildenafil", alsoKnownAs: ["viagra", "sildenafil"], action: .stop, startDay: -1,
                          quote: "Viagra (sildenafil) & Cialis (tadalafil): stop 1 day before surgery", quotePage: 1),
            DraftMedicine(name: "Tadalafil", alsoKnownAs: ["cialis", "tadalafil"], action: .stop, startDay: -1,
                          quote: "Viagra (sildenafil) & Cialis (tadalafil): stop 1 day before surgery", quotePage: 1),
        ]
        draft.tasks = [
            DraftTask(title: "Bring your inhalers, eye drops and creams to the hospital", dueDay: 0,
                      quote: "Bring any inhalers, eye drops or creams to the hospital unless otherwise instructed by the HSS pharmacy", quotePage: 1),
        ]
        return draft
    }

    // MARK: - After surgery (made-up discharge paper)

    private static func afterSurgery() -> DraftPlan {
        var draft = DraftPlan(procedure: "Knee replacement", paper: .afterSurgery)
        draft.isSample = true
        draft.medicines = [
            DraftMedicine(name: "Acetaminophen", alsoKnownAs: ["tylenol", "acetaminophen"], action: .take, startDay: 1, endDay: 14,
                          strength: "500 mg", amount: "2 tablets", timesOfDay: [360, 840, 1320],
                          quote: "Acetaminophen 1000 mg by mouth every 8 hours for pain.", quotePage: 1),
            DraftMedicine(name: "Aspirin 81 mg", alsoKnownAs: ["aspirin", "baby aspirin"], action: .take, startDay: 1, endDay: 35,
                          strength: "81 mg", amount: "1 tablet", timesOfDay: [480, 1200], reason: "Prevents blood clots after surgery.",
                          quote: "Aspirin 81 mg by mouth twice a day for 35 days to prevent blood clots.", quotePage: 1),
            DraftMedicine(name: "Oxycodone", action: .takeAsNeeded, startDay: 1, endDay: 10, strength: "5 mg", amount: "1 tablet",
                          onlyIf: "Severe pain that other medicines don\u{2019}t help", minHoursBetween: 6, maxPerDay: 4,
                          quote: "Oxycodone 5 mg every 6 hours as needed for severe pain. Do not drive.", quotePage: 1),
        ]
        draft.rules = [
            DraftRule(title: "No driving", isAllowed: false, condition: "While you take oxycodone",
                      quote: "Do not drive while taking narcotic pain medicine.", quotePage: 1),
            DraftRule(title: "Showers", isAllowed: true, startDay: 3,
                      quote: "You may shower 3 days after surgery. Keep the dressing dry.", quotePage: 1),
        ]
        draft.tasks = [
            DraftTask(title: "Call to book your check-up for 2 weeks after surgery", dueDay: 2,
                      quote: "Follow up with your surgeon in 2 weeks. Call the office to schedule.", quotePage: 1),
        ]
        draft.goals = [
            DraftGoal(title: "Walk", detail: "Short walks with your walker", symbol: "figure.walk", target: 3, startDay: 1),
            DraftGoal(title: "Knee exercises", detail: "The exercises from your physical therapist",
                      symbol: "figure.strengthtraining.functional", target: 2, startDay: 1),
        ]
        draft.contacts = [
            DraftContact(name: "Surgeon\u{2019}s office", detail: "Questions about your surgery", phone: "2015550142"),
            DraftContact(name: "Hospital pharmacy", detail: "Questions about your medicines", phone: "2015550143", role: .pharmacy),
        ]
        return draft
    }
}
