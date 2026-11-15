//
//  PlanFacts.swift
//  Remedy
//
//  what the rules read from a plan, the saved plan conforms in persistence
//

import Foundation

// one taken or skipped dose
protocol DoseLogFacts {
    var scheduledFor: Date { get }
    var loggedAt: Date { get }
    var status: DoseStatus { get }
}

// one medicine line from a paper
protocol MedicineFacts {
    associatedtype LineID: Hashable
    associatedtype Log: DoseLogFacts

    // stays the same for the line, used in ids
    var lineID: LineID { get }
    var name: String { get }
    var alsoKnownAs: [String] { get }
    var isGroup: Bool { get }
    var action: MedicineAction { get }
    var startDay: Int? { get }
    var endDay: Int? { get }
    var strength: String { get }
    var amount: String { get }
    var timesOfDay: [Int] { get }
    var foodNote: String { get }
    var onlyIf: String { get }
    var minHoursBetween: Int? { get }
    var maxPerDay: Int? { get }
    var lastGivenAt: Date? { get }
    var hospitalDoseAt: Date? { get }
    var reason: String { get }
    var quote: String { get }
    var quotePage: Int? { get }
    var paper: PaperKind { get }
    var isConfirmed: Bool { get }
    var doseLogs: [Log] { get }
}

// one rule like no driving
protocol RuleFacts {
    associatedtype LineID: Hashable

    var lineID: LineID { get }
    var title: String { get }
    var isAllowed: Bool { get }
    var condition: String { get }
    var startDay: Int? { get }
    var endDay: Int? { get }
    var quote: String { get }
    var quotePage: Int? { get }
    var paper: PaperKind { get }
}

// one to do, a class so two with the same words stay apart
protocol TaskFacts: AnyObject {
    associatedtype LineID: Hashable

    var lineID: LineID { get }
    var title: String { get }
    var dueDay: Int? { get }
    var isDone: Bool { get }
    var doneAt: Date? { get }
    var quote: String { get }
    var quotePage: Int? { get }
    var paperRaw: String { get }
    var paper: PaperKind { get }
}

// one visit
protocol VisitFacts {
    associatedtype LineID: Hashable

    var lineID: LineID { get }
    var title: String { get }
    var date: Date { get }
    var place: String { get }
    var bring: [String] { get }
    var quote: String { get }
    var quotePage: Int? { get }
    var paper: PaperKind { get }
}

// one phone number
protocol ContactFacts {
    var name: String { get }
    var detail: String { get }
    var phone: String { get }
    var role: ContactRole { get }
}

// the whole plan
protocol PlanFacts {
    associatedtype Medicine: MedicineFacts
    associatedtype Rule: RuleFacts
    associatedtype ToDo: TaskFacts
    associatedtype Visit: VisitFacts
    associatedtype Contact: ContactFacts

    var procedure: String { get }
    var surgeryDate: Date? { get }
    var dischargeDate: Date? { get }
    var arrivalTime: Date? { get }
    var hospitalName: String? { get }
    var medicines: [Medicine] { get }
    var rules: [Rule] { get }
    var tasks: [ToDo] { get }
    var appointments: [Visit] { get }
    var contacts: [Contact] { get }
}
