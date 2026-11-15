//
//  ReadabilityWords.swift
//  Remedy
//
//  small pure helpers that make rows easy to skim: the time at the start of a second line
//

import Foundation

// splits rows into a bold time and the rest for easier reading
enum ReadabilityWords {

    // the leading time or day word of a line, like "2:00 PM", "8 AM" or "Friday", and the rest
    static func splitLeadingTime(_ text: String) -> (lead: String, rest: String) {
        for pattern in patterns {
            if let range = text.range(of: pattern, options: [.regularExpression, .anchored]) {
                return (String(text[range]), String(text[range.upperBound...]))
            }
        }
        return ("", text)
    }

    private static let patterns = [
        #"\d{1,2}(:\d{2})?\s?[AaPp]\.?[Mm]\.?"#,
        #"(Today|Tomorrow|Tonight|Yesterday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\b"#,
    ]

}
