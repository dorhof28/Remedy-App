//
//  TodayRows.swift
//  Remedy
//
//  display data for today
//

import Foundation
import SwiftData

// MARK: - Which Today to show

// which today screen to show
enum TodayLayout: Equatable {
    case noPlan             // nothing scanned yet
    case needsSurgeryDate   // papers saved, but we don't know the date
    case beforeSurgery      // Day -1 and earlier
    case surgeryDay         // Day 0
    case afterSurgery       // Day +1 and later
}

// MARK: - Before surgery: the one thing to do today

// the big card at the top before surgery
struct BeforeTopCard {
    enum Kind: Equatable {
        case stopToday      // "Stop these today" + "I've put them away"
        case nextStop       // nothing today, here's the next change
        case surgeryDay     // today is the day
        case allClear       // nothing left to stop before surgery
    }

    let kind: Kind
    let symbol: String          // SF Symbol for the top label
    let tone: Tone
    let eyebrow: String         // "Today"
    let title: String           // "Stop taking these today"
    let names: [String]         // "Ibuprofen (Motrin)", one per line
    let nameSymbol: String      // icon in front of each name
    let detail: String          // "These cause blood thinning."
    let buttonTitle: String?    // nil = no button
    let isDone: Bool            // the patient already tapped the button
    let doneText: String        // shown instead of the button once done

    // what VoiceOver reads for the whole card
    var spokenLabel: String {
        let list = PlainText.list(names)
        return [eyebrow, title, list, detail].filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

// MARK: - A simple line in a list

// icon + title + grey detail
struct TodayRow: Identifiable {
    let id: String
    let symbol: String
    let tone: Tone
    let title: String
    let detail: String
    var pillShape: String = ""
    var pillColor: String = ""

    var spokenLabel: String {
        detail.isEmpty ? title : "\(title). \(detail)"
    }
}

// MARK: - To-dos

// one to do
struct TaskRow: Identifiable {
    let task: CareTask
    let title: String           // "Bring your inhalers..."
    let detail: String          // "Due today" / "Done at 9:12 AM"
    let isDone: Bool
    var isLate = false

    var id: PersistentIdentifier { task.persistentModelID }

    // done is good, late is careful, else plain
    var detailTone: Tone { isDone ? .good : (isLate ? .caution : .neutral) }

    var spokenLabel: String { "\(title). \(detail)" }
    var spokenHint: String { isDone ? "Double-tap to mark as not done." : "Double-tap to mark as done." }
}

// MARK: - After surgery: the dose card

// one medicine inside the dose card
struct DoseLine: Identifiable {
    let id: DoseSlot.ID
    let name: String            // "Acetaminophen 500 mg"
    let how: String             // "2 tablets · With food"
    let pillShape: String
    let pillColor: String
}

// the big card at the top after surgery what to take right now
struct NowDoseCard {
    enum Kind: Equatable {
        case due        // it's time: "I took it" / "Skip"
        case missed     // late: still lets them log it
        case next       // nothing now, here's the next one
        case allDone    // nothing left today
        case noDoses    // no set-time medicines today at all
    }

    let kind: Kind
    let symbol: String
    let tone: Tone
    let eyebrow: String         // "Due now · 2:00 PM"
    let title: String           // "Acetaminophen 500 mg" or "2 medicines"
    let detail: String          // "in 3 h 25 min"
    let lines: [DoseLine]
    let slots: [DoseSlot]       // what "I took it" logs

    var showsButtons: Bool { kind == .due || kind == .missed }

    var spokenLabel: String {
        let names = lines.map { "\($0.name), \($0.how)" }
        return ([eyebrow, title, detail] + names).filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

// "3 of 5 taken today" under the dose card
struct DoseProgress {
    let taken: Int
    let total: Int
    let text: String            // "3 of 5 taken today"
    let detail: String          // "1 missed" / ""
    let tone: Tone

    var spokenLabel: String { detail.isEmpty ? text : "\(text), \(detail)" }
    let spokenHint = "Shows all of today\u{2019}s doses."
}

// one dose in the "Today's doses" sheet
struct DoseListRow: Identifiable {
    let slot: DoseSlot
    let timeText: String        // "2:00 PM"
    let name: String
    let how: String
    let stateText: String       // "Taken at 2:04 PM" / "Missed" / "Later"
    let tone: Tone

    var id: DoseSlot.ID { slot.id }
    var state: DoseSlotState { slot.state }

    var spokenLabel: String { "\(timeText), \(name), \(stateText)" }
    var spokenHint: String {
        slot.log == nil ? "Double-tap to mark as taken." : "Double-tap to remove this entry."
    }
}

// morning / Afternoon / Evening in the sheet
struct DoseSection: Identifiable {
    let period: DayPeriod
    let title: String
    let rows: [DoseListRow]
    var id: DayPeriod { period }
}

// MARK: - After surgery: only-when-needed medicines

// one only when needed medicine
struct AsNeededRow: Identifiable {
    let medicine: MedicineInstruction
    let name: String            // "Oxycodone 5 mg"
    let status: String          // "Can take one now, if needed" / "Next OK at 3:20 PM"
    let detail: String          // "Only for severe pain... · Last at 9:20 AM"
    let tone: Tone
    let canTake: Bool
    let buttonTitle: String     // "I took one"

    var id: PersistentIdentifier { medicine.persistentModelID }
    var spokenLabel: String { "\(name). \(status). \(detail)" }
}

// MARK: - After surgery: daily goals

// one daily goal
struct GoalTile: Identifiable {
    let goal: DailyGoal
    let title: String           // "Walk"
    let symbol: String
    let count: Int
    let target: Int
    let countText: String       // "2 of 3"
    let isComplete: Bool
    var amountText: String = ""     // "10 reps"
    var buttonTitle: String = "Done one"

    var id: PersistentIdentifier { goal.persistentModelID }
    var tone: Tone { isComplete ? .good : .info }
    var spokenLabel: String { amountText.isEmpty ? "\(title), \(countText)" : "\(title), \(amountText), \(countText)" }
}

// MARK: - Undo

// what the last tap did so the bar at the bottom can undo it
struct TodayUndo: Identifiable {
    let id = UUID()
    let message: String                     // "Marked as taken"
    let perform: (ModelContext) -> Void     // puts it back
}

extension TaskRow {
}

// a row under "Coming up"
struct ComingUpRow: Identifiable {
    enum Kind: Equatable { case stop, visit }
    let id: String
    let kind: Kind
    let title: String
    let detail: String
    var detailTone: Tone = .neutral
    var visit: Appointment? = nil
}

