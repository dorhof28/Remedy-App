//
//  PaperRuleTests.swift
//  RemedyTests
//
//  rule 6 and the paper check: which paper is followed when two papers disagree
//

import Foundation
import Testing
@testable import Remedy

@Suite struct NewerPaperRuleTests {

    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ text: String) -> Date { Fixtures.date(text) }

    @Test func newerSurgeryTeamPaperWinsEvenOneDayLater() {
        let older = NewerPaperRule.PaperFacts(giver: .anotherDoctor, printed: day("2026-11-01"))
        let newer = NewerPaperRule.PaperFacts(giver: .hospital, printed: day("2026-11-02"))
        #expect(NewerPaperRule.decide(older, newer, calendar: calendar) == .newerWins(.fromSurgeryTeam))
        // order of the arguments does not matter
        #expect(NewerPaperRule.decide(newer, older, calendar: calendar) == .newerWins(.fromSurgeryTeam))
    }

    @Test func anotherGiverWinsOnlyAMonthOrMoreLater() {
        let older = NewerPaperRule.PaperFacts(giver: .surgeonsOffice, printed: day("2026-10-01"))
        let close = NewerPaperRule.PaperFacts(giver: .pharmacy, printed: day("2026-10-31"))
        let month = NewerPaperRule.PaperFacts(giver: .pharmacy, printed: day("2026-11-01"))
        #expect(NewerPaperRule.decide(older, close, calendar: calendar) == .ask(.tooClose))
        #expect(NewerPaperRule.decide(older, month, calendar: calendar) == .newerWins(.monthApart))
    }

    @Test func missingOrSamePrintedDateNeverPicks() {
        let dated = NewerPaperRule.PaperFacts(giver: .anotherDoctor, printed: day("2026-11-01"))
        let undated = NewerPaperRule.PaperFacts(giver: .surgeonsOffice, printed: nil)
        let sameDay = NewerPaperRule.PaperFacts(giver: .hospital, printed: day("2026-11-01").addingTimeInterval(3600 * 5))
        #expect(NewerPaperRule.decide(dated, undated, calendar: calendar) == .ask(.noPrintedDate))
        #expect(NewerPaperRule.decide(dated, sameDay, calendar: calendar) == .ask(.samePrintedDay))
    }

    @Test func daysApartIsWholeDaysEitherOrder() {
        let a = NewerPaperRule.PaperFacts(giver: .pharmacy, printed: day("2026-11-01"))
        let b = NewerPaperRule.PaperFacts(giver: .pharmacy, printed: day("2026-11-11"))
        #expect(NewerPaperRule.daysApart(a, b, calendar: calendar) == 10)
        #expect(NewerPaperRule.daysApart(b, a, calendar: calendar) == 10)
        #expect(NewerPaperRule.daysApart(a, .init(giver: .pharmacy, printed: nil), calendar: calendar) == nil)
    }

    @Test func explanationNamesWhoAndHowLongAfter() {
        let text = NewerPaperRule.explanation(.ask(.tooClose), newerGiver: .pharmacy, daysApart: 1)
        #expect(text == "The newer paper is from the pharmacy, 1 day later, so Remedy doesn\u{2019}t pick.")
        let doctor = NewerPaperRule.explanation(.ask(.tooClose), newerGiver: .anotherDoctor, daysApart: 12)
        #expect(doctor.contains("another doctor, 12 days later"))
        #expect(NewerPaperRule.explanation(.newerWins(.fromSurgeryTeam), newerGiver: .hospital, daysApart: 3)
            .contains("surgery team"))
    }
}

@Suite struct PaperCheckTests {

    @Test func samePlanOnTwoPapersAgrees() {
        let a = Fixtures.item(id: 0, source: .surgeryTeam, printed: "2026-11-01", action: .stop, start: -7, end: 0)
        let b = Fixtures.item(id: 1, source: .specialist, printed: "2026-11-03", action: .stop, start: -7, end: 0)
        let result = PaperCheck.run([a, b])
        #expect(result.findings.count == 1)
        #expect(result.findings[0].color == .green)
        #expect(result.losingItems.isEmpty)
    }

    @Test func differentDoctorsCloseTogetherIsRedAndNotPicked() {
        let a = Fixtures.item(id: 0, source: .specialist, printed: "2026-11-01", action: .stop, start: -5, end: 0)
        let b = Fixtures.item(id: 1, source: .primaryCare, printed: "2026-11-05", action: .take)
        let finding = PaperCheck.run([a, b]).findings[0]
        #expect(finding.color == .red)
        #expect(finding.rule == .differentDoctors)
        #expect(finding.kind == .differentAction)
        #expect(finding.winnerPaperID == nil)
    }

    @Test func newerSurgeryTeamPaperIsBlueAndFollowed() {
        let other = Fixtures.item(id: 0, source: .specialist, printed: "2026-11-01", action: .take)
        let surgery = Fixtures.item(id: 1, source: .surgeryTeam, printed: "2026-11-04", action: .stop, start: -7, end: 0)
        let finding = PaperCheck.run([other, surgery]).findings[0]
        #expect(finding.color == .blue)
        #expect(finding.rule == .surgeryTeamCovers)
        #expect(finding.winnerPaperID == surgery.paperID)
        // a pre-op paper speaks for the days up to surgery
        #expect(finding.period == DayRange(start: nil, end: 0))
    }

    @Test func surgeryTeamOlderAndOtherNewerIsRedWithSurgeryTeamAsDefault() {
        let surgery = Fixtures.item(id: 0, source: .surgeryTeam, printed: "2026-11-01", action: .stop, start: -7, end: 0)
        let other = Fixtures.item(id: 1, source: .specialist, printed: "2026-11-04", action: .take)
        let finding = PaperCheck.run([surgery, other]).findings[0]
        #expect(finding.color == .red)
        // while red the surgery team's line is the one reminders follow
        #expect(finding.defaultPaperID == surgery.paperID)
    }

    @Test func monthLaterFromAnyoneIsBlue() {
        let a = Fixtures.item(id: 0, source: .specialist, printed: "2026-09-01", action: .take, amount: "1 tablet")
        let b = Fixtures.item(id: 1, source: .other, printed: "2026-10-15", action: .take, amount: "2 tablets")
        let finding = PaperCheck.run([a, b]).findings[0]
        #expect(finding.color == .blue)
        #expect(finding.rule == .muchLater)
        #expect(finding.winnerPaperID == b.paperID)
    }

    @Test func missingPrintedDateIsRed() {
        let a = Fixtures.item(id: 0, source: .surgeryTeam, printed: nil, action: .stop, start: -7, end: 0)
        let b = Fixtures.item(id: 1, source: .surgeryTeam, printed: "2026-11-05", action: .take)
        let finding = PaperCheck.run([a, b]).findings[0]
        #expect(finding.color == .red)
        #expect(finding.rule == .noPrintedDate)
    }

    @Test func savedNotePicksThePaper() {
        let a = Fixtures.item(id: 0, source: .specialist, printed: "2026-11-01", action: .stop, start: -5, end: 0)
        let b = Fixtures.item(id: 1, source: .primaryCare, printed: "2026-11-05", action: .take)
        let key = PaperCheck.run([a, b]).findings[0].key
        let picked = PaperCheck.run([a, b], notes: [key: a.paperID]).findings[0]
        #expect(picked.isResolved)
        #expect(picked.winnerPaperID == a.paperID)
        // a note pointing at a paper that is not in the finding is ignored
        let stray = PaperCheck.run([a, b], notes: [key: UUID()]).findings[0]
        #expect(stray.winnerPaperID == nil)
    }

    @Test func recordMedicineNoPaperNamesIsAGap() {
        let paper = Fixtures.item(id: 0, source: .surgeryTeam, printed: "2026-11-01", name: "Aspirin", action: .take)
        let record = Fixtures.item(id: 1, source: .hospitalRecord, printed: "2026-11-01", name: "Metformin", action: .take)
        let result = PaperCheck.run([paper, record])
        #expect(result.gaps.map(\.name) == ["Metformin"])
    }

    @Test func otherDoctorsMedicineTheSurgeryTeamSkipsIsANote() {
        let surgery = Fixtures.item(id: 0, source: .surgeryTeam, printed: "2026-11-01", name: "Aspirin", action: .take)
        let other = Fixtures.item(id: 1, source: .specialist, printed: "2026-11-02", name: "Warfarin", action: .take)
        let notes = PaperCheck.run([surgery, other]).findings.filter { $0.rule == .notMentioned }
        #expect(notes.count == 1)
        #expect(notes[0].medicine == "Warfarin")
    }

    @Test func twoLinesOnOnePaperAreNotCompared() {
        let paper = UUID()
        var a = Fixtures.item(id: 0, source: .surgeryTeam, printed: "2026-11-01", action: .stop, start: -7, end: -1)
        var b = Fixtures.item(id: 1, source: .surgeryTeam, printed: "2026-11-01", action: .take, start: 1, end: 30)
        a.paperID = paper
        b.paperID = paper
        #expect(PaperCheck.run([a, b]).findings.isEmpty)
    }

    @Test func dayRangeIntersectionAndOutside() {
        let upTo = DayRange(start: nil, end: 0)
        #expect(upTo.contains(-100) && upTo.contains(0) && !upTo.contains(1))
        #expect(upTo.intersection(DayRange(start: 2, end: 5)) == nil)
        #expect(upTo.intersection(DayRange(start: -3, end: 5)) == DayRange(start: -3, end: 0))
        #expect(upTo.outside == DayRange(start: 1, end: nil))
        #expect(DayRange(start: 0, end: nil).outside == DayRange(start: nil, end: -1))
    }
}
