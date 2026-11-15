//
//  AIChoiceLines.swift
//  Remedy
//
//  the three plain lines that say what reads the page, what hides names and what makes the plan
//  and a red second line when a pick is not ready, nothing else
//

import Foundation

// one line on the reader choice card and what stops it from working
struct AIChoiceLine: Equatable {
    let text: String
    let problem: String?    // shown under the line in red, nil when ready
}

// the three lines under who reads the papers: reading the page, hiding your name, making your plan
struct AIChoiceLines: Equatable {
    static let notReady = "Not ready: choose another"

    let page: AIChoiceLine
    let hiding: AIChoiceLine
    let reading: AIChoiceLine

    // builds the lines from the saved choices, a problem marks the line that cannot run
    static func make(_ settings: ModelSettings, problem: AIProblem?) -> AIChoiceLines {
        let how = settings.redactBeforePlanning ? settings.redactionChoice.summaryName : "off in Settings"
        var pageProblem: String?
        var hidingProblem: String?
        var readingProblem: String?
        switch problem {
        case .hiding?: hidingProblem = notReady
        case .pageReading?: pageProblem = notReady
        case .reading?: readingProblem = notReady
        case nil: break
        }
        return AIChoiceLines(
            page: AIChoiceLine(text: "Reading the page: \(settings.readingChoice.summaryName)", problem: pageProblem),
            hiding: AIChoiceLine(text: "Hiding names: \(how)", problem: hidingProblem),
            reading: AIChoiceLine(text: "Making the plan: \(settings.plannerChoice.summaryName)", problem: readingProblem))
    }
}
