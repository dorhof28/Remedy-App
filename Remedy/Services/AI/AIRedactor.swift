//
//  AIRedactor.swift
//  Remedy
//
//  removes personal info on the phone with rules then the phone ai
//

import Foundation
import os
import FoundationModels

// what the phone AI hands back the personal words it found
@Generable
nonisolated struct FoundPersonalInfo {
    @Guide(description: "Each personal detail about the patient or their family, copied exactly as written")
    var items: [String]
}

enum AIRedactor {

    static let instructions = """
        You find personal details in a patient's hospital paper so they can be hidden.
        Find: the patient's name, family members' names, home address, birth date, \
        record, account or insurance numbers, and the patient's own phone number or email.
        Do NOT include: doctors, nurses, hospitals, offices or their phone numbers, \
        medicine names, doses, days, times or instructions.
        Copy each detail exactly as it is written. If there are none, return an empty list.
        """

    // both passes page by page
    static func redact(_ pages: [String]) async -> [RedactedPage] {
        var result: [RedactedPage] = []
        for page in pages {
            // pass 1 the fixed rules
            let ruled = Redactor.redact(page)

            // pass 2 the phone AI
            guard AppleAI.isPhoneAvailable else {
                result.append(ruled)
                continue
            }
            var text = ruled.text
            var removed = ruled.removedCount
            for chunk in chunks(of: text) {
                let found = await findPersonalInfo(in: chunk)
                let (newText, count) = blackOut(found, in: text)
                text = newText
                removed += count
            }
            result.append(RedactedPage(text: text, removedCount: removed))
        }
        return result
    }

    // MARK: - Private

    // asks the phone model which words are personal
    private static func findPersonalInfo(in text: String) async -> [String] {
        do {
            let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
            let response = try await session.respond(to: text, generating: FoundPersonalInfo.self)
            return response.content.items
        } catch {
            PlanReaders.log.error("Phone AI redaction failed: \(error.localizedDescription)")
            return []
        }
    }

    // skips mistakes so a dose like 325 is never hidden
    static func blackOut(_ items: [String], in text: String) -> (String, Int) {
        var result = text
        var count = 0
        for raw in items {
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let letters = item.filter(\.isLetter).count
            let digits = item.filter(\.isNumber).count
            if item.count < 3 || item.contains(Redactor.mark) { continue }   // too short / already hidden
            if letters == 0 && digits < 7 { continue }                      // short number = probably a dose

            // replace each place it appears
            while let range = result.range(of: item, options: .caseInsensitive) {
                result.replaceSubrange(range, with: Redactor.mark)
                count += 1
            }
        }
        return (result, count)
    }

    // splits a page into pieces the phone model can hold
    private static func chunks(of text: String, size: Int = 2500) -> [String] {
        var pieces: [String] = []
        var current = ""
        for line in text.components(separatedBy: .newlines) {
            if current.count + line.count > size && !current.isEmpty {
                pieces.append(current)
                current = ""
            }
            current += line + "\n"
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }
}
