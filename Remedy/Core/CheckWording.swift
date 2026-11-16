//
//  CheckWording.swift
//  Remedy
//
//  plain words for a paper check finding, shared by ask today and medicine detail
//

import Foundation

// what one paper says, with who wrote it
nonisolated struct CheckQuote: Equatable {
    let doctor: String
    let text: String
}

// the words on one paper check card
nonisolated struct CheckMessage: Equatable {
    // blue once the office has picked a paper, red while it is open
    let color: CheckColor
    // "Your papers disagree"
    let headline: String
    // what the app follows and when to ask, blank when there is nothing to add
    let detail: String
    // headline and detail short enough for a row
    let oneLine: String
    // newer paper first, one per line
    let quotes: [CheckQuote]
}

nonisolated extension Finding {

    // nil when the papers agree or the surgery team's paper covers it
    func message(surgeryDate: Date) -> CheckMessage? {
        let newerDoctor = Self.doctor(newer)
        let quotes = items.map { CheckQuote(doctor: Self.doctor($0), text: $0.quote) }

        if rule == .notMentioned {
            let paper = (newer.doctorName ?? "").isEmpty ? "other doctor\u{2019}s" : newer.doctorName ?? ""
            if isAsked {
                return CheckMessage(color: .blue, headline: "You asked the surgeon\u{2019}s office about \(medicine)", detail: "",
                                    oneLine: "You asked the surgeon\u{2019}s office about \(medicine).", quotes: quotes)
            }
            return CheckMessage(color: .blue, headline: "Your surgery papers don\u{2019}t mention \(medicine)",
                                detail: "Your \(paper) paper lists \(medicine), but your surgery papers don\u{2019}t say anything about it. "
                                    + "You may want to ask the surgeon\u{2019}s office.",
                                oneLine: "Your surgery papers don\u{2019}t mention this. You may want to ask the surgeon\u{2019}s office.",
                                quotes: quotes)
        }
        // the surgery team's paper decides, nothing to say, the medicine's source line shows which paper
        if rule == .surgeryTeamCovers { return nil }
        if color == .blue {
            return CheckMessage(color: .blue, headline: "Your newer paper from \(newerDoctor) changed this", detail: "",
                                oneLine: "The newer paper from \(newerDoctor) changed this.", quotes: quotes)
        }
        guard color == .red else { return nil }

        let followed = winnerPaperID ?? defaultPaperID
        let followedDoctor = Self.doctor(items.first { $0.paperID == followed } ?? newer)
        if isResolved {
            let who = isCircle ? "You" : "Your care team"
            return CheckMessage(color: .blue, headline: "\(who) chose the paper from \(followedDoctor)",
                                detail: "Remedy follows that paper.",
                                oneLine: "\(who) chose the paper from \(followedDoctor).", quotes: quotes)
        }

        if isCircle {
            return CheckMessage(color: .red, headline: "Your papers disagree",
                                detail: "\(reason). Remedy is not following any paper for this until you choose, "
                                    + "so there are no reminders for it. Choose which paper to follow.",
                                oneLine: "Your papers disagree. Choose which paper to follow.", quotes: quotes)
        }
        let ask = askByDay.map { "by \(DayMath.shortDate(forDay: $0, from: surgeryDate))" } ?? "now"
        let until = rule == .noPrintedDate ? "\(reason). Until you choose" : "Until you hear back"
        return CheckMessage(color: .red, headline: "Your papers disagree",
                            detail: "\(until), reminders use the paper from \(followedDoctor). That isn\u{2019}t Remedy saying it\u{2019}s right. Ask your care team \(ask).",
                            oneLine: "Your papers disagree. Ask your care team \(ask).", quotes: quotes)
    }

    // why the rules cannot pick a paper, blank when they can
    var reason: String {
        switch rule {
        case .circle: return "Remedy cannot tell which is newest"
        case .noPrintedDate: return "One of these papers has no date, so Remedy cannot tell which is newer"
        case .genericNewer: return "The newer paper names a whole group of medicines, and the older paper names this one on its own"
        case .differentDoctors: return "Different doctors wrote these papers less than a month apart"
        case .agree, .sameTeam, .surgeryTeamCovers, .muchLater, .notMentioned: return ""
        }
    }

    // the doctor's name from the paper, or your care team
    private static func doctor(_ item: CheckItem) -> String {
        let name = item.doctorName ?? ""
        return name.isEmpty ? "your care team" : name
    }
}
