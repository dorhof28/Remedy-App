//
//  PromptExamples.swift
//  Remedy
//
//  made up example papers with the right answers
//  the ai sees a few in its prompt and the tests check our code against all of them
//  add a json file to Resources/PromptExamples to grow the set
//

import Foundation

// one example paper and what the right answer is
nonisolated struct PromptExample: Decodable {
    let id: String
    let paper: String               // beforeSurgery or afterSurgery
    let checkedBy: String           // who checked the answer like a doctor empty if not yet
    let note: String                // what this example teaches
    let source: String?             // the sample pdf it came from
    let pageText: String
    let answer: [String]            // one line per item the ai should find
    let checks: Checks?

    // what the tests check
    nonisolated struct Checks: Decodable {
        let surgeryDate: String?        // yyyy-MM-dd
        let names: [String]?            // must be hidden
    }

    var isChecked: Bool { !checkedBy.isEmpty }
}

// the example papers and answers in the prompt
enum PromptExamples {

    // more examples means a longer prompt so only a few go in
    static let maxInPrompt = 3

    // every example json in the app
    static var all: [PromptExample] {
        let decoder = JSONDecoder()
        let urls = Bundle.allBundles.flatMap { $0.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [] }
        var seen: Set<String> = []
        return urls
            .filter { $0.lastPathComponent.hasPrefix("example-") && seen.insert($0.lastPathComponent).inserted }
            .compactMap { try? decoder.decode(PromptExample.self, from: Data(contentsOf: $0)) }
            .sorted { $0.id < $1.id }
    }

    // doctor checked ones first then the same kind of paper
    static func pick(for paper: PaperKind, limit: Int = maxInPrompt) -> [PromptExample] {
        let kind = paper == .beforeSurgery ? "beforeSurgery" : "afterSurgery"
        return all.sorted { a, b in
            if a.isChecked != b.isChecked { return a.isChecked }
            return (a.paper == kind) && (b.paper != kind)
        }
        .prefix(limit)
        .map { $0 }
    }

    // the examples written into the prompt
    static func promptText(for paper: PaperKind, limit: Int = maxInPrompt) -> String {
        pick(for: paper, limit: limit).enumerated().map { index, example in
            """
            Example \(index + 1) papers
            \(example.pageText)

            Example \(index + 1) answer
            \(example.answer.map { "- " + $0 }.joined(separator: "\n"))
            """
        }.joined(separator: "\n\n")
    }
}
