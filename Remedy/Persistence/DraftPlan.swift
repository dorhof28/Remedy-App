//
//  DraftPlan.swift
//  Remedy
//
//  plan from the ai before its saved
//

import Foundation

// everything found in one set of papers
struct DraftPlan {
    var procedure: String = ""
    var surgeryDate: Date?              // usually none: HSS said most papers don't say it
    var paper: PaperKind                // which papers these are
    var source: PlanSource = .scan
    var isSample: Bool = false                      // pre-made sample paper, not a real scan
    var paperSource: PaperSource = .surgeryTeam     // who gave the patient this paper
    var paperField: PaperField?                     // only for a specialist
    var otherKindText: String = ""                  // typed kind when the doctor kind is Other
    var doctorName: String = ""
    var hospitalName: String = ""
    var printedDate: Date?                          // date printed on the paper

    var medicines: [DraftMedicine] = []
    var rules: [DraftRule] = []
    var tasks: [DraftTask] = []
    var appointments: [DraftAppointment] = []
    var goals: [DraftGoal] = []
    var contacts: [DraftContact] = []
    var pages: [DraftPage] = []
    var readBy: String = ""             // which ai read it
    var leftOut: [LeftOutItem] = []     // what the ai said that was not on the papers
    var warnings: [String] = []         // what the patient should double-check ("page 2 couldn't be read")

    // every page's words, for checking quotes against the paper
    var pageText: String { pages.map(\.redactedText).joined(separator: "\n") }

}

// medicine before its saved
struct DraftMedicine: Identifiable {
    let id = UUID()
    var name: String
    var alsoKnownAs: [String] = []
    var isGroup: Bool = false
    var action: MedicineAction
    var startDay: Int?
    var endDay: Int?
    var strength: String = ""
    var amount: String = ""
    var timesOfDay: [Int] = []          // minutes after midnight
    var foodNote: String = ""
    var onlyIf: String = ""
    var minHoursBetween: Int?
    var maxPerDay: Int?
    var reason: String = ""
    var exception: String = ""
    var lastGivenText: String = ""      // the paper's "Last given" words, checked when saved
    var lastGivenPick: Date?            // the patient's AM or PM answer when the paper left it out
    var hospitalDoseAnswer: Bool?       // twice a day with an unreadable time: did the hospital give this dose
    var hospitalDoseAt: Date?           // the paper's dose time that question was about
    var quote: String
    var quotePage: Int?
    var isConfirmed: Bool = false       // the patient confirmed it
}

// rule before its saved
struct DraftRule: Identifiable {
    let id = UUID()
    var title: String
    var isAllowed: Bool
    var condition: String = ""
    var startDay: Int?
    var endDay: Int?
    var quote: String
    var quotePage: Int?
    var isConfirmed: Bool = false
}

// to do before its saved
struct DraftTask: Identifiable {
    let id = UUID()
    var title: String
    var dueDay: Int?
    var quote: String
    var quotePage: Int?
    var isConfirmed: Bool = false
}

// visit before its saved
struct DraftAppointment: Identifiable {
    let id = UUID()
    var title: String
    var date: Date
    var doctor: String = ""
    var place: String = ""
    var address: String = ""
    var phone: String = ""
    var purpose: String = ""
    var bring: [String] = []
    var quote: String
    var quotePage: Int?
    var isConfirmed: Bool = false
}

// goal before its saved
struct DraftGoal: Identifiable {
    let id = UUID()
    var title: String
    var detail: String = ""
    var symbol: String = "checkmark.circle"
    var target: Int = 1
    var startDay: Int?
    var endDay: Int?
    var quote: String = ""
}

// contact before its saved
struct DraftContact: Identifiable {
    let id = UUID()
    var name: String
    var detail: String = ""
    var phone: String
    var role: ContactRole = .careTeam
    // only when the papers list one
    var email: String = ""
}

// a page and its text
struct DraftPage {
    var pageNumber: Int
    var redactedText: String
}

extension DraftPlan {

    // visit papers read by the ai plus the record items picked with them
    // the papers win on surgery facts, record items are added and never replace what the papers say
    func addingRecord(_ record: DraftPlan) -> DraftPlan {
        var merged = self
        if merged.surgeryDate == nil { merged.surgeryDate = record.surgeryDate }
        if merged.procedure.isEmpty { merged.procedure = record.procedure }
        if merged.hospitalName.isEmpty { merged.hospitalName = record.hospitalName }
        let named = Set(medicines.map { $0.name.lowercased() })
        merged.medicines += record.medicines.filter { !named.contains($0.name.lowercased()) }
        let visits = Set(appointments.map { "\($0.title.lowercased())|\($0.date)" })
        merged.appointments += record.appointments.filter { !visits.contains("\($0.title.lowercased())|\($0.date)") }
        return merged
    }
}
