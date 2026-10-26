//
//  AIRedactor.swift
//  Remedy
//
//  removes personal info on the phone with rules names then the phone ai
//

import Foundation
import os
import FoundationModels

// what the phone AI hands back the personal words it found
@Generable
nonisolated struct FoundPersonalInfo {
    @Guide(description: "Full names of the patient and their family, copied exactly as written")
    var names: [String]
    @Guide(description: "Other personal details: home address, birth date, record, account or insurance numbers, the patient's own phone or email. Copied exactly")
    var details: [String]
}

enum AIRedactor {

    static let instructions = """
        You find personal details in a patient's hospital paper so they can be hidden.
        Find the patient's name and family members' names, and their home address, birth date, \
        record, account or insurance numbers, and own phone number or email.
        Do NOT include doctors, nurses, hospitals, offices or their phone numbers, \
        medicine names, doses, days, times or instructions.
        Copy each detail exactly as it is written. If there are none, return empty lists.
        """

    // off the typed in names and rules do a better job and the phone model missed too much
    static let usesPhoneAI = false

    // rules and names first then the phone ai page by page
    static func redact(_ pages: [String]) async -> [RedactedPage] {
        var result: [RedactedPage] = []
        for page in pages {
            let ruled = Redactor.redact(page)
            guard usesPhoneAI, AppleAI.isPhoneAvailable else {
                result.append(ruled)
                continue
            }
            var text = ruled.text
            var hidden = ruled.hidden
            for chunk in chunks(of: text) {
                guard let found = await findPersonalInfo(in: chunk) else { continue }
                let names = found.names.filter(isRealFind)
                let details = found.details.filter(isRealFind)
                text = blackOut(names + details, in: text).0
                let (spread, words) = Redactor.hideNameWords(names, in: text)
                text = spread
                hidden += names + details + words
            }
            let count = text.components(separatedBy: Redactor.mark).count - 1
            result.append(RedactedPage(text: text, removedCount: count, hidden: hidden))
        }
        return result
    }

    // MARK: - Private

    // the tagging model is tuned for pulling things out of text
    private static let model = SystemLanguageModel(useCase: .contentTagging)

    // asks the phone model which words are personal
    private static func findPersonalInfo(in text: String) async -> FoundPersonalInfo? {
        do {
            let session = LanguageModelSession(model: model, instructions: instructions)
            let response = try await session.respond(to: text, generating: FoundPersonalInfo.self,
                                                     options: GenerationOptions(sampling: .greedy))
            PlanReaders.log.info("Phone AI found \(response.content.names.count) names and \(response.content.details.count) details")
            return response.content
        } catch {
            PlanReaders.log.error("Phone AI redaction failed: \(error.localizedDescription)")
            return nil
        }
    }

    // throws out doctors medicines and doses the model got wrong
    private static func isRealFind(_ raw: String) -> Bool {
        let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = item.split(separator: " ").map(String.init)
        let letters = item.filter(\.isLetter).count
        let digits = item.filter(\.isNumber).count
        if item.count < 3 || item.contains(Redactor.mark) { return false }
        if letters == 0 && digits < 7 { return false }                  // short number = probably a dose
        if words.allSatisfy(MedicalWords.isProtected) { return false }
        let lower = item.lowercased()
        return !(lower.hasPrefix("dr") || lower.contains(" md") || lower.contains(", md"))
    }

    // hides each place an item appears
    static func blackOut(_ items: [String], in text: String) -> (String, Int) {
        var result = text
        var count = 0
        for raw in items {
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isRealFind(item) else { continue }
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
