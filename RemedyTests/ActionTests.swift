//
//  ActionTests.swift
//  RemedyTests
//
//  what a tap saves: doses and undo, as needed limits, edits, contacts, to-dos and check-ins
//

import Foundation
import SwiftData
import Testing
@testable import Remedy

@MainActor
@Suite(.serialized) struct ActionTests {

    private let surgery = Fixtures.date("2026-11-20")

    private func plan(in context: ModelContext) -> CarePlan {
        var draft = DraftPlan(paper: .afterSurgery)
        draft.surgeryDate = surgery
        draft.medicines = [
            DraftMedicine(name: "Aspirin", action: .take, timesOfDay: [480, 1200], quote: "Aspirin twice a day", isConfirmed: true),
            DraftMedicine(name: "Oxycodone", action: .takeAsNeeded, minHoursBetween: 6, maxPerDay: 2,
                          quote: "Oxycodone every 6 hours as needed", isConfirmed: true),
        ]
        draft.tasks = [DraftTask(title: "Change the dressing", dueDay: 2, quote: "Change dressing day 2", isConfirmed: true)]
        return PlanImporter.save(draft, in: context)
    }

    private func medicine(_ name: String, in plan: CarePlan) -> MedicineInstruction {
        plan.medicines.first { $0.name == name }!
    }

    @Test func takenDoseUndoesBackToNothing() throws {
        let context = try Fixtures.context()
        let aspirin = medicine("Aspirin", in: plan(in: context))
        let time = DayMath.date(forDay: 1, minute: 480, from: surgery)
        let undo = DoseActions.log(aspirin, scheduledFor: time, as: .taken, now: time, in: context)
        #expect(aspirin.doseLogs.count == 1)
        DoseActions.undo(undo, in: context)
        #expect(aspirin.doseLogs.isEmpty)
    }

    @Test func secondAnswerChangesTheSameDose() throws {
        let context = try Fixtures.context()
        let aspirin = medicine("Aspirin", in: plan(in: context))
        let time = DayMath.date(forDay: 1, minute: 480, from: surgery)
        DoseActions.log(aspirin, scheduledFor: time, as: .skipped, now: time, in: context)
        let undo = DoseActions.log(aspirin, scheduledFor: time.addingTimeInterval(30), as: .taken, now: time, in: context)
        #expect(aspirin.doseLogs.count == 1)
        #expect(aspirin.doseLogs[0].status == .taken)
        DoseActions.undo(undo, in: context)
        #expect(aspirin.doseLogs[0].status == .skipped)
    }

    @Test func changedDoseIsMarkedAsThePatients() throws {
        let context = try Fixtures.context()
        let aspirin = medicine("Aspirin", in: plan(in: context))
        let time = DayMath.date(forDay: 1, minute: 480, from: surgery)
        let log = DoseActions.change(aspirin, scheduledFor: time, to: .taken, takenAt: time.addingTimeInterval(1800), in: context)
        #expect(log.changedByYou)
        #expect(log.loggedAt == time.addingTimeInterval(1800))
    }

    @Test func asNeededWaitsTheGapAndStopsAtTheMost() throws {
        let context = try Fixtures.context()
        let oxy = medicine("Oxycodone", in: plan(in: context))
        let morning = DayMath.date(forDay: 1, minute: 8 * 60, from: surgery)
        DoseActions.logAsNeeded(oxy, now: morning, in: context)
        let soon = DoseSchedule.asNeededStatus(for: oxy, now: morning.addingTimeInterval(3600))
        #expect(soon.takenToday == 1)
        #expect(soon.nextAllowed == morning.addingTimeInterval(6 * 3600))
        #expect(!soon.reachedMax)

        DoseActions.logAsNeeded(oxy, now: morning.addingTimeInterval(7 * 3600), in: context)
        let later = DoseSchedule.asNeededStatus(for: oxy, now: morning.addingTimeInterval(8 * 3600))
        #expect(later.takenToday == 2)
        #expect(later.reachedMax)
        // a new day starts the count again
        let tomorrow = DoseSchedule.asNeededStatus(for: oxy, now: DayMath.date(forDay: 2, minute: 9 * 60, from: surgery))
        #expect(tomorrow.takenToday == 0)
        #expect(!tomorrow.reachedMax)
    }

    @Test func doseStatesFollowTheClock() {
        let time = DayMath.date(forDay: 1, minute: 480, from: surgery)
        let none: DoseLog? = nil
        #expect(DoseSchedule.state(at: time, log: none, now: time.addingTimeInterval(-6 * 3600)) == .upcoming)
        #expect(DoseSchedule.state(at: time, log: none, now: time) == .due)
        #expect(DoseSchedule.state(at: time, log: none, now: time.addingTimeInterval(24 * 3600)) == .missed)
    }

    @Test func firstHomeDoseStartsFromTheHospitalDose() throws {
        let context = try Fixtures.context()
        let oxy = medicine("Oxycodone", in: plan(in: context))
        oxy.timesOfDay = [6 * 60, 12 * 60, 18 * 60]
        oxy.maxPerDay = nil
        oxy.lastGivenAt = DayMath.date(forDay: 1, minute: 10 * 60, from: surgery)
        let times = DoseSchedule.doseTimes(for: oxy, onDay: 1, from: surgery)
        // the first home dose is 6 hours after 10 AM, and no paper time sits within 6 hours after that
        #expect(times == [DayMath.date(forDay: 1, minute: 16 * 60, from: surgery)])
    }

    @Test func editingPurposeGoesToTheRightField() throws {
        let context = try Fixtures.context()
        let plan = plan(in: context)
        let oxy = medicine("Oxycodone", in: plan)
        var draft = MedicineActions.draft(for: oxy)
        draft.purpose = "  bad pain "
        MedicineActions.save(draft, to: oxy, in: plan, now: surgery, context: context)
        #expect(oxy.onlyIf == "bad pain")
        #expect(oxy.changedByYouAt == surgery)

        let aspirin = medicine("Aspirin", in: plan)
        var daily = MedicineActions.draft(for: aspirin)
        daily.purpose = "blood clots"
        MedicineActions.save(daily, to: aspirin, in: plan, now: surgery, context: context)
        #expect(aspirin.reason == "blood clots")
        #expect(MedicineActions.draft(for: aspirin).purpose == "blood clots")
    }

    @Test func renamedMedicineDropsOldBrandNames() throws {
        let context = try Fixtures.context()
        let plan = plan(in: context)
        let aspirin = medicine("Aspirin", in: plan)
        aspirin.alsoKnownAs = ["bayer"]
        var draft = MedicineActions.draft(for: aspirin)
        draft.name = "Clopidogrel"
        MedicineActions.save(draft, to: aspirin, in: plan, now: surgery, context: context)
        #expect(aspirin.alsoKnownAs.isEmpty)
    }

    @Test func contactsAddChangeAndRemove() throws {
        let context = try Fixtures.context()
        let plan = plan(in: context)
        ContactActions.add(name: "Sam Rivera", phone: "201-555-0123", detail: "Daughter", to: plan, in: context)
        let contact = try #require(plan.contacts.first { $0.name == "Sam Rivera" })
        ContactActions.update(contact, name: "Sam R.", phone: "2015550124", detail: "Son", in: context)
        #expect(contact.name == "Sam R.")
        #expect(contact.detail == "Son")
        ContactActions.remove(contact, in: context)
        #expect(!plan.contacts.contains { $0.name == "Sam R." })
    }

    @Test func todoTogglesDoneAndBack() throws {
        let context = try Fixtures.context()
        let task = try #require(plan(in: context).tasks.first)
        TaskActions.toggle(task, now: surgery, in: context)
        #expect(task.isDone)
        TaskActions.toggle(task, now: surgery, in: context)
        #expect(!task.isDone)
    }

    @Test func secondCheckInTheSameDayEditsTheFirst() throws {
        let context = try Fixtures.context()
        let plan = plan(in: context)
        let now = DayMath.date(forDay: 2, minute: 9 * 60, from: surgery)
        let viewModel = CheckInViewModel(plan: plan, now: now)
        viewModel.save(pain: 4, ticked: [], note: "sore", in: context)
        viewModel.save(pain: 12, ticked: [], note: " better ", in: context)
        let saved = try context.fetch(FetchDescriptor<CheckIn>())
        #expect(saved.count == 1)
        #expect(saved[0].pain == 10)
        #expect(saved[0].note == "better")
        #expect(saved[0].editedAt != nil)
    }

    @Test func surgeryDateMoveKeepsPlanDays() throws {
        let context = try Fixtures.context()
        let plan = plan(in: context)
        let task = try #require(plan.tasks.first)
        PlanActions.setSurgeryDate(Fixtures.date("2026-11-27"), on: plan, in: context)
        #expect(plan.surgeryDate == Fixtures.date("2026-11-27"))
        // to-dos are kept as days from surgery so they move with it
        #expect(task.dueDay == 2)
    }
}
