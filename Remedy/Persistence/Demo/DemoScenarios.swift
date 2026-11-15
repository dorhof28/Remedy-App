//
//  DemoScenarios.swift
//  Remedy
//
//  DEMO ONLY the fake patients in the Demo mode picker in Settings
//  every date is counted from today so each case shows the phase it says
//

import Foundation

// the fake patients in the demo mode picker
enum DemoScenario: String, CaseIterable, Identifiable {

    // which papers
    case beforeOnly, afterOnly, bothPapers
    // when the surgery is
    case surgeryIn10Days, surgeryTomorrow, surgeryToday, threeDaysAfter, threeWeeksAfter, longAgo
    // tricky plans
    case conflictingPapers, missingDoctorPhone, manyStopMedicines, asNeededMedicines, appointmentsToday, overdueTodos

    var id: String { rawValue }

    // the sections of the picker
    enum Group: CaseIterable, Identifiable {
        case featured, papers, dates, tricky
        var id: Self { self }

        var title: String {
            switch self {
            case .featured: return "Start here"
            case .papers: return "Which papers"
            case .dates: return "When the surgery is"
            case .tricky: return "Tricky plans"
            }
        }
    }

    var group: Group {
        switch self {
        // the everyday plans shown first, one tap each
        case .surgeryIn10Days, .surgeryTomorrow, .threeDaysAfter, .conflictingPapers: return .featured
        case .beforeOnly, .afterOnly, .bothPapers: return .papers
        case .surgeryToday, .threeWeeksAfter, .longAgo: return .dates
        case .missingDoctorPhone, .manyStopMedicines, .asNeededMedicines, .appointmentsToday, .overdueTodos: return .tricky
        }
    }

    static func scenarios(in group: Group) -> [DemoScenario] {
        allCases.filter { $0.group == group }
    }

    var title: String {
        switch self {
        case .beforeOnly: return "Before-surgery papers only"
        case .afterOnly: return "After-surgery papers only"
        case .bothPapers: return "Both sets of papers"
        case .surgeryIn10Days: return "Surgery in 10 days"
        case .surgeryTomorrow: return "Surgery tomorrow"
        case .surgeryToday: return "Surgery today"
        case .threeDaysAfter: return "3 days after surgery"
        case .threeWeeksAfter: return "3 weeks after surgery"
        case .longAgo: return "Surgery long ago"
        case .conflictingPapers: return "Papers disagree"
        case .missingDoctorPhone: return "No doctor phone numbers"
        case .manyStopMedicines: return "Many stop medicines"
        case .asNeededMedicines: return "As-needed medicines"
        case .appointmentsToday: return "Appointments today"
        case .overdueTodos: return "Overdue to-dos"
        }
    }

    var detail: String {
        switch self {
        case .beforeOnly: return "Knee replacement, 10 days away"
        case .afterOnly: return "Knee replacement, 5 days ago"
        case .bothPapers: return "Before and after papers, 2 days after"
        case .surgeryIn10Days: return "Full plan, getting ready"
        case .surgeryTomorrow: return "Full plan, the night before"
        case .surgeryToday: return "Full plan, surgery day"
        case .threeDaysAfter: return "Full plan, early recovery"
        case .threeWeeksAfter: return "Full plan, getting stronger"
        case .longAgo: return "Full plan, 4 months later"
        case .conflictingPapers: return "Two doctors give different Eliquis stop days"
        case .missingDoctorPhone: return "Contacts and visits with no phone"
        case .manyStopMedicines: return "Six or more medicines to stop"
        case .asNeededMedicines: return "Pain pills with limits, day after surgery"
        case .appointmentsToday: return "Two visits on today\u{2019}s date"
        case .overdueTodos: return "Day 5 with to-dos still open"
        }
    }

    var symbol: String {
        switch self {
        case .beforeOnly: return "doc.text"
        case .afterOnly: return "cross.case"
        case .bothPapers: return "doc.on.doc"
        case .surgeryIn10Days: return "calendar"
        case .surgeryTomorrow: return "moon.stars"
        case .surgeryToday: return "sun.max"
        case .threeDaysAfter: return "bed.double"
        case .threeWeeksAfter: return "figure.walk"
        case .longAgo: return "clock.arrow.circlepath"
        case .conflictingPapers: return "exclamationmark.triangle"
        case .missingDoctorPhone: return "phone.down"
        case .manyStopMedicines: return "pills"
        case .asNeededMedicines: return "bandage"
        case .appointmentsToday: return "calendar.badge.clock"
        case .overdueTodos: return "checklist"
        }
    }

    // MARK: - What it loads

    // how a scenario is made: the sample plan or papers saved one by one
    enum Build {
        // the app's own full sample plan, surgery this many days from today
        case samplePlan(surgeryInDays: Int)
        // papers saved one by one the way a scan saves them
        case papers([DraftPlan])
    }

    // days from today to surgery, negative when it is already done
    var surgeryInDays: Int {
        switch self {
        case .beforeOnly: return 10
        case .afterOnly: return -5
        case .bothPapers: return -2
        case .surgeryIn10Days: return 10
        case .surgeryTomorrow: return 1
        case .surgeryToday: return 0
        case .threeDaysAfter: return -3
        case .threeWeeksAfter: return -21
        case .longAgo: return -120
        case .conflictingPapers: return 9
        case .missingDoctorPhone: return 4
        case .manyStopMedicines: return 8
        case .asNeededMedicines: return -1
        case .appointmentsToday: return -14
        case .overdueTodos: return -5
        }
    }

    // the recipe for this scenario, dated from today
    func build(today: Date) -> Build {
        let days = surgeryInDays
        switch self {
        case .surgeryIn10Days, .surgeryTomorrow, .surgeryToday, .threeDaysAfter, .threeWeeksAfter, .longAgo:
            return .samplePlan(surgeryInDays: days)
        case .beforeOnly:
            return .papers(Self.rebased([DianeDrafts.beforeSurgery()], surgeryIn: days, today: today))
        case .afterOnly:
            return .papers(Self.rebased([DianeDrafts.afterSurgery()], surgeryIn: days, today: today))
        case .bothPapers:
            return .papers(Self.rebased([DianeDrafts.beforeSurgery(), DianeDrafts.afterSurgery()], surgeryIn: days, today: today))
        case .conflictingPapers:
            // the surgery team leaves eliquis to the specialists, who disagree, so the patient is asked to call
            var surgery = SamplePatients.b1()
            surgery.medicines.removeAll { $0.name.hasPrefix("Apixaban") }
            return .papers(Self.rebased([surgery, SamplePatients.b2(), SamplePatients.b5(), SamplePatients.b3()],
                                        surgeryIn: days, today: today))
        case .missingDoctorPhone:
            var drafts = Self.rebased([DianeDrafts.beforeSurgery(), DianeDrafts.afterSurgery()], surgeryIn: days, today: today)
            for index in drafts.indices {
                for contact in drafts[index].contacts.indices { drafts[index].contacts[contact].phone = "" }
                for visit in drafts[index].appointments.indices { drafts[index].appointments[visit].phone = "" }
            }
            return .papers(drafts)
        case .manyStopMedicines:
            return .papers(Self.rebased([SamplePatients.c2(), SamplePatients.c3()], surgeryIn: days, today: today))
        case .asNeededMedicines:
            return .papers(Self.rebased([SamplePatients.b1(), SamplePatients.b4()], surgeryIn: days, today: today))
        case .appointmentsToday:
            var drafts = Self.rebased([DianeDrafts.afterSurgery()], surgeryIn: days, today: today)
            // the follow up and a therapy visit both land on today
            let midnight = DayMath.calendar.startOfDay(for: today)
            if let index = drafts[0].appointments.indices.first {
                drafts[0].appointments[index].date = midnight.addingTimeInterval(10.5 * 3600)
            }
            drafts[0].appointments.append(DraftAppointment(
                title: "Physical therapy", date: midnight.addingTimeInterval(15 * 3600), doctor: "Jordan Lee, PT",
                place: "Outpatient Rehab Center (SAMPLE)", phone: "2015550144",
                quote: "Physical therapy visit this afternoon at 3:00 PM.", quotePage: 2))
            return .papers(drafts)
        case .overdueTodos:
            var drafts = Self.rebased([DianeDrafts.beforeSurgery(), DianeDrafts.afterSurgery()], surgeryIn: days, today: today)
            drafts[1].tasks.append(DraftTask(title: "Call to book your physical therapy visit", dueDay: 2,
                                             quote: "Call the PT office to book your first visit.", quotePage: 2))
            return .papers(drafts)
        }
    }

    // moves papers to the surgery day, printed dates and visits keep their gap to it
    static func rebased(_ drafts: [DraftPlan], surgeryIn days: Int, today: Date) -> [DraftPlan] {
        let calendar = DayMath.calendar
        let surgery = LaunchOptions.shifted(calendar.startOfDay(for: today), byDays: days)
        return drafts.map { original in
            var draft = original
            let old = draft.surgeryDate
            draft.surgeryDate = surgery
            draft.isSample = true
            if let old {
                let move = calendar.dateComponents([.day], from: calendar.startOfDay(for: old), to: surgery).day ?? 0
                draft.printedDate = draft.printedDate.map { LaunchOptions.shifted($0, byDays: move) }
                for index in draft.appointments.indices {
                    draft.appointments[index].date = LaunchOptions.shifted(draft.appointments[index].date, byDays: move)
                }
            } else {
                // papers with no date: the before paper printed 5 days ahead, the after paper on the day
                draft.printedDate = draft.printedDate ?? LaunchOptions.shifted(surgery, byDays: draft.paper == .beforeSurgery ? -5 : 0)
                for index in draft.appointments.indices {
                    let time = draft.appointments[index].date.timeIntervalSince(calendar.startOfDay(for: draft.appointments[index].date))
                    draft.appointments[index].date = LaunchOptions.shifted(surgery, byDays: 14).addingTimeInterval(time)
                }
            }
            return draft
        }
    }
}
