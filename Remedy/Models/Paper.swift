//
//  Paper.swift
//  Remedy
//
//  one set of papers: who gave it and when it was printed
//

import Foundation
import SwiftData

// one set of papers: before or after surgery, who gave it and when it was printed
@Model
final class Paper {

    var id: UUID = UUID()
    var kindRaw: String = PaperKind.beforeSurgery.rawValue
    var sourceRaw: String = PaperSource.surgeryTeam.rawValue
    var fieldRaw: String?
    var doctorName: String?
    // the hospital from the letterhead or logo words
    var hospitalName: String?
    // what the patient typed when the kind of doctor is Other
    var otherKindText: String = ""
    var printedDate: Date?
    var addedAt: Date = Date()

    // the plan it belongs to
    var plan: CarePlan?

    init(kind: PaperKind, source: PaperSource, field: PaperField? = nil,
         doctorName: String? = nil, printedDate: Date? = nil, addedAt: Date = Date()) {
        self.kindRaw = kind.rawValue
        self.sourceRaw = source.rawValue
        self.fieldRaw = source == .specialist ? field?.rawValue : nil
        self.doctorName = doctorName
        self.printedDate = printedDate
        self.addedAt = addedAt
    }

    var kind: PaperKind {
        get { PaperKind(rawValue: kindRaw) ?? .beforeSurgery }
        set { kindRaw = newValue.rawValue }
    }

    var source: PaperSource {
        get { PaperSource(rawValue: sourceRaw) ?? .other }
        set { sourceRaw = newValue.rawValue }
    }

    var field: PaperField? {
        get { fieldRaw.flatMap { PaperField(rawValue: $0) } }
        set { fieldRaw = newValue?.rawValue }
    }

    var isSurgeryTeam: Bool { source == .surgeryTeam }

    // printed date when there is one
    var sortDate: Date { printedDate ?? addedAt }
}
