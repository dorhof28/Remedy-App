//
//  PhoneFormat.swift
//  Remedy
//
//  phone numbers the way people read them
//

import Foundation

// phone numbers in the usual us shape
nonisolated enum PhoneFormat {

    // "5550111" "555-0111", "2015550142" "(201) 555-0142", anything else as typed
    static func text(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        // letters or an extension mean the paper wrote it its own way
        guard trimmed.allSatisfy({ $0.isNumber || " ()-.+".contains($0) }) else { return trimmed }
        let d = Array(digits)
        switch d.count {
        case 3:
            return digits
        case 7:
            return "\(String(d[0..<3]))-\(String(d[3..<7]))"
        case 10:
            return "(\(String(d[0..<3]))) \(String(d[3..<6]))-\(String(d[6..<10]))"
        case 11 where d[0] == "1":
            return "1 (\(String(d[1..<4]))) \(String(d[4..<7]))-\(String(d[7..<11]))"
        default:
            return trimmed
        }
    }
}
