//
//  PromptExampleTests.swift
//  RemedyTests
//
//  checks our own code gets every example paper right
//

import Foundation
import Testing
@testable import Remedy

@MainActor
struct PromptExampleTests {

    @Test("The example papers are in the app")
    func examplesLoad() {
        #expect(PromptExamples.all.count >= 4)
    }

    @Test("Each stop day comes out right from the words on the paper")
    func stopDays() {
        for example in PromptExamples.all {
            for (medicine, day) in example.checks?.stopDays ?? [:] {
                #expect(AIPlanConverter.headingDay(of: medicine, in: example.pageText) == day,
                        "\(example.id): \(medicine) should stop on day \(day)")
            }
        }
    }

    @Test("A date written as a date not a day count is left for the patient")
    func noStopDay() {
        for example in PromptExamples.all {
            for medicine in example.checks?.noStopDay ?? [] {
                #expect(AIPlanConverter.headingDay(of: medicine, in: example.pageText) == nil, "\(example.id): \(medicine)")
            }
        }
    }

    @Test("The surgery date is found and the visit date is not used")
    func surgeryDates() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for example in PromptExamples.all {
            guard let expected = example.checks?.surgeryDate else { continue }
            let found = SurgeryDateFinder.find(in: [example.pageText]).map { formatter.string(from: $0) }
            #expect(found == expected, "\(example.id)")
        }
    }

    @Test("Names are hidden before anything leaves the phone")
    func namesHidden() {
        for example in PromptExamples.all {
            let names = example.checks?.names ?? []
            // the patient typed their name on the scan screen
            let page = Redactor.redact(example.pageText, names: names).text
            for word in PatientNames.words(names) {
                #expect(!page.lowercased().contains(word), "\(example.id): \(word) was not hidden")
            }
        }
    }

    @Test("Typed names are hidden even when the camera misreads a letter")
    func typedNamesWithTypos() {
        let (text, _) = PatientNames.hide(in: "Patient SMLTH, JOHN came in", names: ["John Smith"])
        #expect(!text.contains("SMLTH"))
        #expect(!text.contains("JOHN"))
    }
}
