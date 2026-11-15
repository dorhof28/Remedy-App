//
//  PaperCheckReport+Repeated.swift
//  Remedy
//
//  two papers that say the same thing about a medicine show as one row
//

import Foundation
import SwiftData

extension PaperCheckReport {

    // older lines that say exactly what a newer paper says, lists show only the newer one
    // the paper check still shows both papers as agreeing
    var repeatedLines: Set<PersistentIdentifier> {
        var ids = Set<PersistentIdentifier>()
        for finding in result.findings where finding.color == .green && !finding.isCircle {
            let newer = finding.newer
            guard !newer.isGroup else { continue }
            for item in finding.items.dropFirst() where !item.isGroup && item.action == newer.action
                && item.startDay == newer.startDay && item.endDay == newer.endDay
                && item.paperID != newer.paperID && medicines.indices.contains(item.id) {
                ids.insert(medicines[item.id].persistentModelID)
            }
        }
        return ids
    }
}
