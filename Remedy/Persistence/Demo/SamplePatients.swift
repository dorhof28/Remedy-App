//
//  SamplePatients.swift
//  Remedy
//
//  DEMO ONLY drafts for the three fake patients in SamplePapers/ one draft per paper
//  knee papers (A1-A3) gallbladder papers (B1-B4) hernia papers (C1-C3)
//

import Foundation

// three fake patients with several papers each, for the paper check demo
enum SamplePatients {

    // all drafts for one patient in paper order
    static func kneePapers() -> [DraftPlan] { [a1(), a2(), a3()] }
    static func gallbladderPapers() -> [DraftPlan] { [b1(), b2(), b3(), b4()] }
    static func herniaPapers() -> [DraftPlan] { [c1(), c2(), c3()] }

    // the draft whose quotes all appear in these pages and the most of them
    static func draft(matching pages: [String]) -> DraftPlan? {
        // lower case with single spaces so quotes match the page text
        func squash(_ text: String) -> String {
            text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        let text = squash(pages.joined(separator: " "))
        var best: (draft: DraftPlan, hits: Int)?
        for draft in kneePapers() + gallbladderPapers() + herniaPapers() {
            let quotes = (draft.medicines.map(\.quote) + draft.rules.map(\.quote) + draft.tasks.map(\.quote))
                .map(squash).filter { !$0.isEmpty }
            guard !quotes.isEmpty, quotes.allSatisfy({ text.contains($0) }) else { continue }
            if quotes.count > (best?.hits ?? 0) { best = (draft, quotes.count) }
        }
        return best?.draft
    }

    private static func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        DateComponents(calendar: Calendar.current, year: year, month: month, day: day, hour: hour, minute: minute).date ?? Date()
    }

    // a draft with the paper's giver, doctor and printed date filled in
    private static func base(_ procedure: String, surgery: Date, paper: PaperKind = .beforeSurgery, source: PaperSource,
                             field: PaperField? = nil, doctor: String, printed: Date?) -> DraftPlan {
        var draft = DraftPlan(procedure: procedure, paper: paper)
        draft.surgeryDate = surgery
        draft.paperSource = source
        draft.paperField = field
        draft.doctorName = doctor
        draft.printedDate = printed
        draft.readBy = "Sample papers (demo)"
        draft.isSample = true
        return draft
    }

    private static let marcusSurgery = day(2026, 12, 14)
    private static let lenaSurgery = day(2026, 12, 22)
    private static let frankSurgery = day(2027, 1, 14)

    // MARK: - Right knee replacement

    // knee: heart doctor's letter
    static func a1() -> DraftPlan {
        var d = base("Right knee replacement", surgery: marcusSurgery, source: .specialist, field: .heart,
                     doctor: "Dr. Priya Raman", printed: day(2026, 11, 20))
        d.medicines = [
            DraftMedicine(name: "Aspirin 81 mg", alsoKnownAs: ["baby aspirin", "aspirin"], action: .okToTake, strength: "81 mg",
                          quote: "Continue aspirin 81 mg once daily. Do not stop it before surgery.", quotePage: 1),
            DraftMedicine(name: "Metoprolol succinate", alsoKnownAs: ["metoprolol"], action: .okToTake, strength: "25 mg",
                          exception: "Take with a sip of water the morning of surgery.",
                          quote: "Continue metoprolol succinate 25 mg every morning, including the morning of surgery. Take it with a sip of water.", quotePage: 1),
            DraftMedicine(name: "Atorvastatin", alsoKnownAs: ["lipitor", "atorvastatin"], action: .okToTake, strength: "40 mg",
                          quote: "Continue atorvastatin 40 mg at bedtime.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "Northfield Heart Clinic", detail: "Chest pain or trouble breathing", phone: "5550111")]
        return d
    }

    // knee: surgeon's before surgery paper
    static func a2() -> DraftPlan {
        var d = base("Right knee replacement", surgery: marcusSurgery, source: .surgeryTeam,
                     doctor: "Dr. Alan Whitfield", printed: day(2026, 12, 1))
        let stop = "Stop these medicines 7 days before surgery"
        d.medicines = [
            DraftMedicine(name: "Aspirin", alsoKnownAs: ["baby aspirin", "aspirin"], action: .stop, startDay: -7, quote: "\(stop): Aspirin", quotePage: 1),
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .stop, startDay: -7,
                          quote: "Ibuprofen (Advil, Motrin) and naproxen (Aleve)", quotePage: 1),
            DraftMedicine(name: "Naproxen", alsoKnownAs: ["aleve", "naproxen"], action: .stop, startDay: -7,
                          quote: "Ibuprofen (Advil, Motrin) and naproxen (Aleve)", quotePage: 1),
            DraftMedicine(name: "Fish oil", alsoKnownAs: ["fish oil", "omega-3"], action: .stop, startDay: -7, quote: "Fish oil", quotePage: 1),
            DraftMedicine(name: "Lisinopril", alsoKnownAs: ["lisinopril"], action: .stop, startDay: 0, endDay: 0, strength: "10 mg",
                          quote: "Do not take lisinopril 10 mg the morning of surgery.", quotePage: 1),
        ]
        d.rules = [
            DraftRule(title: "Nothing to eat after midnight", isAllowed: false, startDay: -1, endDay: 0,
                      quote: "Nothing to eat after midnight.", quotePage: 1),
            DraftRule(title: "Clear liquids until 2 hours before you arrive", isAllowed: true, startDay: 0, endDay: 0,
                      quote: "You may drink clear liquids until 2 hours before you arrive.", quotePage: 1),
        ]
        d.tasks = [DraftTask(title: "Arrive at 6:00 AM", dueDay: 0, quote: "Arrive at 6:00 AM.", quotePage: 1)]
        d.contacts = [DraftContact(name: "Orthopedic Surgery", detail: "Questions about your surgery", phone: "5550122")]
        return d
    }

    // knee: pre-admission testing paper
    static func a3() -> DraftPlan {
        var d = base("Right knee replacement", surgery: marcusSurgery, source: .surgeryTeam,
                     doctor: "Northfield pre-admission testing", printed: day(2026, 12, 4))
        d.medicines = [
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .stop, startDay: -4,
                          quote: "Stop ibuprofen (Advil, Motrin) and naproxen (Aleve) 4 days before surgery.", quotePage: 1),
            DraftMedicine(name: "Naproxen", alsoKnownAs: ["aleve", "naproxen"], action: .stop, startDay: -4,
                          quote: "Stop ibuprofen (Advil, Motrin) and naproxen (Aleve) 4 days before surgery.", quotePage: 1),
            DraftMedicine(name: "Fish oil", alsoKnownAs: ["fish oil", "omega-3"], action: .stop, startDay: -7,
                          quote: "Stop fish oil 7 days before surgery.", quotePage: 1),
            DraftMedicine(name: "Metoprolol succinate", alsoKnownAs: ["metoprolol"], action: .okToTake, startDay: 0, endDay: 0,
                          exception: "Take with a sip of water.",
                          quote: "Take metoprolol the morning of surgery with a sip of water.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "Pre-Admission Testing", detail: "Questions before surgery", phone: "5550133")]
        return d
    }

    // MARK: - Gallbladder removal

    // gallbladder: surgeon's paper
    static func b1() -> DraftPlan {
        var d = base("Gallbladder removal", surgery: lenaSurgery, source: .surgeryTeam,
                     doctor: "Dr. Hannah Cole", printed: day(2026, 11, 10))
        d.medicines = [
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .stop, startDay: -2, strength: "5 mg",
                          quote: "Stop apixaban (Eliquis) 5 mg 2 days before surgery.", quotePage: 1),
            DraftMedicine(name: "Metformin", alsoKnownAs: ["metformin"], action: .stop, startDay: 0, endDay: 0, strength: "500 mg",
                          quote: "Do not take metformin 500 mg the morning of surgery.", quotePage: 1),
            DraftMedicine(name: "Atorvastatin", alsoKnownAs: ["lipitor", "atorvastatin"], action: .okToTake, strength: "20 mg",
                          quote: "Continue atorvastatin 20 mg at bedtime.", quotePage: 1),
        ]
        d.tasks = [DraftTask(title: "Arrive at 7:30 AM", dueDay: 0, quote: "Arrive at 7:30 AM.", quotePage: 1)]
        d.contacts = [DraftContact(name: "General Surgery", detail: "Questions about your surgery", phone: "5550144")]
        return d
    }

    // gallbladder: blood doctor's letter
    static func b2() -> DraftPlan {
        var d = base("Gallbladder removal", surgery: lenaSurgery, source: .specialist, field: .blood,
                     doctor: "Dr. Victor Osei", printed: day(2026, 11, 14))
        d.medicines = [
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .stop, startDay: -3,
                          reason: "No bridging injection.",
                          quote: "Stop Eliquis 3 days before surgery. You do not need a bridging injection.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "Blood and Clotting Clinic", detail: "Questions about Eliquis", phone: "5550155")]
        return d
    }

    // a heart doctor who disagrees with the blood clinic about eliquis, for the papers disagree demo
    static func b5() -> DraftPlan {
        var d = base("Gallbladder removal", surgery: lenaSurgery, source: .specialist, field: .heart,
                     doctor: "Dr. Priya Nand", printed: day(2026, 11, 18))
        d.medicines = [
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .stop, startDay: -5,
                          quote: "SAMPLE: Hold Eliquis for 5 days before your procedure.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "Heart Clinic", detail: "Questions about your heart medicines", phone: "5550177")]
        return d
    }

    // gallbladder: diabetes doctor's letter
    static func b3() -> DraftPlan {
        var d = base("Gallbladder removal", surgery: lenaSurgery, source: .specialist, field: .diabetes,
                     doctor: "Dr. Mei Tanaka", printed: day(2026, 12, 16))
        d.medicines = [
            DraftMedicine(name: "Metformin", alsoKnownAs: ["metformin"], action: .stop, startDay: -2,
                          quote: "Stop metformin 48 hours before surgery.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "Diabetes Center", detail: "Sugar very high or very low", phone: "5550166")]
        return d
    }

    // gallbladder: discharge papers
    static func b4() -> DraftPlan {
        var d = base("Gallbladder removal", surgery: lenaSurgery, paper: .afterSurgery, source: .surgeryTeam,
                     doctor: "Northfield general surgery team", printed: day(2026, 12, 23))
        d.medicines = [
            DraftMedicine(name: "Oxycodone", alsoKnownAs: ["oxycodone"], action: .takeAsNeeded, startDay: 0, strength: "5 mg", amount: "1 tablet",
                          onlyIf: "Pain", minHoursBetween: 4, maxPerDay: 6,
                          quote: "Oxycodone 5 mg: 1 tablet every 4 hours as needed for pain. No more than 6 a day.", quotePage: 1),
            DraftMedicine(name: "Acetaminophen", alsoKnownAs: ["tylenol", "acetaminophen"], action: .take, startDay: 0, strength: "500 mg", amount: "2 tablets",
                          minHoursBetween: 6, quote: "Acetaminophen 500 mg: 2 tablets every 6 hours.", quotePage: 1),
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .okToTake, startDay: 2, strength: "5 mg",
                          reason: "Restart twice daily.", quote: "Restart Eliquis 5 mg twice daily on December 24.", quotePage: 1),
            DraftMedicine(name: "Metformin", alsoKnownAs: ["metformin"], action: .okToTake, startDay: 1,
                          reason: "Restart when you are eating normally.", quote: "Restart metformin when you are eating normally.", quotePage: 1),
        ]
        d.appointments = [
            DraftAppointment(title: "Visit with Dr. Cole", date: day(2027, 1, 5, hour: 10, minute: 15), doctor: "Dr. Hannah Cole",
                             place: "Northfield General Hospital (SAMPLE)", phone: "5550144",
                             quote: "Visit with Dr. Cole on January 5, 2027 at 10:15 AM.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "General Surgery", detail: "Questions after surgery", phone: "5550144")]
        return d
    }

    // MARK: - Hernia repair

    // hernia: heart doctor's letter
    static func c1() -> DraftPlan {
        var d = base("Hernia repair", surgery: frankSurgery, source: .specialist, field: .heart,
                     doctor: "Dr. Samuel Okafor", printed: day(2026, 12, 28))
        d.medicines = [
            DraftMedicine(name: "Clopidogrel (Plavix)", alsoKnownAs: ["plavix", "clopidogrel"], action: .okToTake, strength: "75 mg",
                          reason: "You have a heart stent.",
                          quote: "You have a heart stent. Do not stop clopidogrel (Plavix) 75 mg for any reason unless I tell you.", quotePage: 1),
            DraftMedicine(name: "Aspirin 81 mg", alsoKnownAs: ["baby aspirin", "aspirin"], action: .okToTake, strength: "81 mg",
                          quote: "Continue aspirin 81 mg.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "Northfield Heart Clinic", detail: "Questions about your heart medicines", phone: "5550177")]
        return d
    }

    // hernia: surgery team's paper
    static func c2() -> DraftPlan {
        var d = base("Hernia repair", surgery: frankSurgery, source: .surgeryTeam,
                     doctor: "Northfield surgery team", printed: day(2027, 1, 4))
        let thinners = "Stop all blood thinners 7 days before surgery, including aspirin, clopidogrel (Plavix), warfarin (Coumadin), apixaban (Eliquis)."
        d.medicines = [
            DraftMedicine(name: "Aspirin", alsoKnownAs: ["baby aspirin", "aspirin"], action: .stop, startDay: -7, quote: thinners, quotePage: 1),
            DraftMedicine(name: "Clopidogrel (Plavix)", alsoKnownAs: ["plavix", "clopidogrel"], action: .stop, startDay: -7, quote: thinners, quotePage: 1),
            DraftMedicine(name: "Warfarin (Coumadin)", alsoKnownAs: ["coumadin", "warfarin"], action: .stop, startDay: -7, quote: thinners, quotePage: 1),
            DraftMedicine(name: "Apixaban (Eliquis)", alsoKnownAs: ["eliquis", "apixaban"], action: .stop, startDay: -7, quote: thinners, quotePage: 1),
            DraftMedicine(name: "Vitamins and supplements", alsoKnownAs: ["vitamins", "supplements"], isGroup: true, action: .stop, startDay: -7,
                          quote: "Stop vitamins and supplements 7 days before surgery.", quotePage: 1),
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .okToTake, endDay: -3,
                          quote: "You may take ibuprofen until 3 days before surgery.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "Northfield General Hospital (SAMPLE)", detail: "Questions before surgery", phone: "5550188")]
        return d
    }

    // no printed date on purpose
    static func c3() -> DraftPlan {
        var d = base("Hernia repair", surgery: frankSurgery, source: .primaryCare, doctor: "Dr. Rachel Kim", printed: nil)
        d.medicines = [
            DraftMedicine(name: "Ibuprofen", alsoKnownAs: ["advil", "motrin", "ibuprofen"], action: .stop, quote: "Stop ibuprofen now.", quotePage: 1),
            DraftMedicine(name: "Acetaminophen", alsoKnownAs: ["tylenol", "acetaminophen"], action: .takeAsNeeded, strength: "500 mg",
                          onlyIf: "Knee pain", maxPerDay: 3,
                          quote: "Use acetaminophen 500 mg up to 3 times a day for knee pain.", quotePage: 1),
        ]
        d.contacts = [DraftContact(name: "Family Medicine", detail: "Questions about your medicines", phone: "5550199")]
        return d
    }
}
