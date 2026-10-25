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

    var medicines: [DraftMedicine] = []
    var rules: [DraftRule] = []
    var tasks: [DraftTask] = []
    var appointments: [DraftAppointment] = []
    var goals: [DraftGoal] = []
    var contacts: [DraftContact] = []
    var pages: [DraftPage] = []
    var readBy: String = ""             // which ai read it
    var warnings: [String] = []         // what the patient should double-check ("page 2 couldn't be read")

    // what patient still has to check
    var uncheckedCount: Int {
        medicines.filter { !$0.isConfirmed }.count
            + rules.filter { !$0.isConfirmed }.count
            + tasks.filter { !$0.isConfirmed }.count
            + appointments.filter { !$0.isConfirmed }.count
    }
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
}

// a page and its text
struct DraftPage {
    var pageNumber: Int
    var redactedText: String
}
