//
//  WarningSigns.swift
//  Remedy
//
//  warning signs from the papers and who to call for each
//

import Foundation

// one sign the paper says to call about
nonisolated struct WarningSign: Identifiable, Equatable {
    let text: String        // from the paper
    let phone: String?      // digits from the paper, or the care team number
    let isEmergency: Bool   // the paper says 911

    var id: String { text }
}

// finds the when to call rules on the papers for the help screen
nonisolated enum WarningSigns {

    // a rule that says to call or get help
    // a "call your doctor for" line from the papers, shown in the check-in and help, never as a rule
    static func isCallSign(isAllowed: Bool, condition: String) -> Bool {
        !isAllowed && condition.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("call")
    }

    static func isWarning(title: String, condition: String, quote: String, isAllowed: Bool) -> Bool {
        guard !isAllowed else { return false }
        let words = "\(title) \(condition) \(quote)".lowercased()
        return ["call", "911", "emergency", "phone"].contains { words.contains($0) }
    }

    // the sign with the number from its own paper line, else the care team number
    static func sign(title: String, condition: String, quote: String, careTeamPhone: String?) -> WarningSign {
        let line = "\(condition) \(quote)"
        let emergency = line.contains("911") || line.lowercased().contains("emergency")
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let own = phone(in: line) {
            return WarningSign(text: text, phone: own, isEmergency: false)
        }
        if emergency {
            return WarningSign(text: text, phone: "911", isEmergency: true)
        }
        return WarningSign(text: text, phone: careTeamPhone, isEmergency: false)
    }

    // first phone number written in the text as digits only
    static func phone(in text: String) -> String? {
        let pattern = #"(?<!\d)(?:\(?\d{3}\)?[\s.-]?)?\d{3}[\s.-]?\d{4}(?!\d)"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range]).filter(\.isNumber)
    }

    // the numbers to show for the ticked signs, 911 first, no repeats
    static func numbers(for ticked: [WarningSign]) -> [String] {
        var result: [String] = []
        for sign in ticked.sorted(by: { $0.isEmergency && !$1.isEmergency }) {
            if let phone = sign.phone, !phone.isEmpty, !result.contains(phone) {
                result.append(phone)
            }
        }
        return result
    }
}
