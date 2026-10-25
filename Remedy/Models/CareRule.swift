//
//  CareRule.swift
//  Remedy
//
//  what you can and cant do
//

import Foundation
import SwiftData

@Model
final class CareRule {

    
    var title: String = ""
    var isAllowed: Bool = false
    var condition: String = ""

    var startDay: Int?
    var endDay: Int?

    // where it came from
    var quote: String = ""
    var quotePage: Int?
    var paperRaw: String = PaperKind.afterSurgery.rawValue

    // the plan it belongs to
    var plan: CarePlan?

    init(title: String, isAllowed: Bool, paper: PaperKind, quote: String) {
        self.title = title
        self.isAllowed = isAllowed
        self.paperRaw = paper.rawValue
        self.quote = quote
    }

    var paper: PaperKind {
        get { PaperKind(rawValue: paperRaw) ?? .afterSurgery }
        set { paperRaw = newValue.rawValue }
    }
}
