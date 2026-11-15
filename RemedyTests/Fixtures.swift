//
//  Fixtures.swift
//  RemedyTests
//
//  small builders the tests share: dates, paper check lines and an in memory store
//

import Foundation
import SwiftData
@testable import Remedy

enum Fixtures {

    // "2026-11-01" or "2026-11-01 14:30" in the app calendar
    static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = DayMath.calendar
        formatter.timeZone = DayMath.calendar.timeZone
        formatter.dateFormat = text.count > 10 ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
        return formatter.date(from: text)!
    }

    // one medicine line from one paper, each call is its own paper
    static func item(id: Int, source: PaperSource, printed: String?, name: String = "Ibuprofen",
                     action: MedicineAction, start: Int? = nil, end: Int? = nil, amount: String = "",
                     kind: PaperKind = .beforeSurgery) -> CheckItem {
        CheckItem(id: id, paperID: UUID(), source: source, field: nil, printedDate: printed.map(date),
                  addedAt: Date(timeIntervalSince1970: TimeInterval(1_000 + id)), paperKind: kind, doctorName: nil,
                  name: name, names: MedicineIdentity.names(name, alsoKnownAs: []), isGroup: false, groupMembers: [],
                  isGeneric: false, action: action, startDay: start, endDay: end, strength: "", amount: amount,
                  quote: "\(name) line \(id)")
    }

    // a fresh store with the app's schema that lives only for the test
    @MainActor
    static func context() throws -> ModelContext {
        let schema = Schema(RemedySchema.models)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        containers.append(container)
        return container.mainContext
    }

    // the context does not keep its container alive
    @MainActor private static var containers: [ModelContainer] = []
}
