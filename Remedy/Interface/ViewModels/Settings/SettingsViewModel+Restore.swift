//
//  SettingsViewModel+Restore.swift
//  Remedy
//
//  the restore sheet for both looks: the steps, the preview of what comes back and the result
//

import Foundation

// one line in the preview of a backup
struct BackupPreviewItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    let value: String
}

extension SettingsViewModel {

    var restoreIntro: String { "Bring back a plan you saved with \u{201C}Make a backup\u{201D}. You see what is in it before anything changes." }
    var restoreSteps: [(symbol: String, text: String)] {
        [("doc.badge.arrow.up", "Choose the backup file from Files"),
         ("key.fill", "Type the password you picked for it"),
         ("checklist", "Check what is inside, then restore")]
    }
    var restoreSafeNote: String { "Nothing on this phone changes until you say yes." }
    var restoreButton: String { hasPlan ? replaceTitle : "Restore this plan" }
    var restoredTitle: String { "Plan restored" }
    var otherFileTitle: String { "Choose another file" }

    // the plan name and date up top, then the counts
    func backupPreview(_ summary: BackupSummary) -> [BackupPreviewItem] {
        [
            BackupPreviewItem(id: "plan", symbol: "cross.case.fill", title: "Plan",
                              value: summary.procedure.isEmpty ? "No surgery name" : summary.procedure),
            BackupPreviewItem(id: "surgery", symbol: "calendar", title: "Surgery",
                              value: summary.surgeryDate.map { $0.formatted(date: .long, time: .omitted) } ?? "No date"),
            BackupPreviewItem(id: "made", symbol: "clock.arrow.circlepath", title: "Backup made",
                              value: summary.madeAt.formatted(date: .abbreviated, time: .shortened)),
            BackupPreviewItem(id: "medicines", symbol: "pills.fill", title: "Medicines", value: "\(summary.medicines)"),
            BackupPreviewItem(id: "papers", symbol: "doc.text.fill", title: "Papers", value: "\(summary.papers)"),
            BackupPreviewItem(id: "doses", symbol: "checkmark.circle.fill", title: "Doses logged", value: "\(summary.doses)"),
            BackupPreviewItem(id: "checkins", symbol: "heart.text.square.fill", title: "Check-ins", value: "\(summary.checkIns)"),
            BackupPreviewItem(id: "photos", symbol: "photo.fill", title: "Photos", value: "\(summary.photos)"),
        ]
    }
}
