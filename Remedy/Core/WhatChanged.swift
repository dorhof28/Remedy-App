//
//  WhatChanged.swift
//  Remedy
//
//  what a newly added paper changed in the plan
//

import Foundation

// what a new paper changes in the plan: new, changed, restarted and not mentioned
nonisolated struct WhatChanged {
    // lines from the new paper
    var new: [CheckItem] = []
    var changed: [CheckItem] = []
    var restarted: [CheckItem] = []
    var stillStopped: [CheckItem] = []
    // old lines missing from a discharge paper that replaces their paper
    var notMentioned: [CheckItem] = []

    // compares the new paper's lines with the lines already in the plan
    init(before: [CheckItem], after: [CheckItem]) {
        let old = before.filter { !$0.isRecord }
        let oldPapers = Set(old.map(\.paperID))
        let added = after.filter { !$0.isRecord && !oldPapers.contains($0.paperID) }

        var seen = Set<String>()
        for item in added where seen.insert(MedicineIdentity.key(item.names, item.names)).inserted {
            let earlier = old.filter { MedicineIdentity.same($0.names, item.names) }
            guard let last = earlier.max(by: { PaperCheck.isNewer($1, than: $0) }) else {
                new.append(item)
                continue
            }
            switch (last.action == .stop, item.action == .stop) {
            case (true, false):
                restarted.append(item)
            case (true, true):
                if PaperCheck.daysDiffer(last, item) { changed.append(item) } else { stillStopped.append(item) }
            case (false, true):
                changed.append(item)
            case (false, false):
                if PaperCheck.kind(last, item) != .agree { changed.append(item) }
            }
        }

        // a discharge paper replaces older papers from the same team
        var missing = Set<String>()
        for paper in added where paper.paperKind == .afterSurgery {
            let onPaper = added.filter { $0.paperID == paper.paperID }
            for item in old where PaperCheck.sameTeam(item, paper) && PaperCheck.isNewer(paper, than: item)
                && !onPaper.contains(where: { MedicineIdentity.same($0.names, item.names) })
                && missing.insert(MedicineIdentity.key(item.names, item.names)).inserted {
                notMentioned.append(item)
            }
        }
    }
}
