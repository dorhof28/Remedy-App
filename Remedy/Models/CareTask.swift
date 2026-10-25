//
//  CareTask.swift
//  Remedy
//
//  something the person has to do
//

import Foundation
import SwiftData

@Model
final class CareTask {

    
    var title: String = ""
    var dueDay: Int?
    var isDone: Bool = false
    var doneAt: Date?

    // where it came from
    var quote: String = ""
    var quotePage: Int?
    var paperRaw: String = PaperKind.beforeSurgery.rawValue

    // the plan it belongs to
    var plan: CarePlan?

    init(title: String, dueDay: Int?, paper: PaperKind, quote: String) {
        self.title = title
        self.dueDay = dueDay
        self.paperRaw = paper.rawValue
        self.quote = quote
    }

    var paper: PaperKind {
        get { PaperKind(rawValue: paperRaw) ?? .beforeSurgery }
        set { paperRaw = newValue.rawValue }
    }
}
