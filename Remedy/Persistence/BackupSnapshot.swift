//
//  BackupSnapshot.swift
//  Remedy
//
//  every saved model as plain codable structs, links kept by id, for the backup file
//

import Foundation
import SwiftData

// the whole database as plain structs, links kept as ids, for the backup file
nonisolated struct BackupSnapshot: Codable, Equatable, Sendable {

    // bump when the layout changes, older apps refuse newer files
    static let currentFormat = 1

    var formatVersion: Int = BackupSnapshot.currentFormat
    var madeAt: Date = Date()

    var plans: [PlanItem] = []
    var medicines: [MedicineItem] = []
    var doseLogs: [DoseLogItem] = []
    var rules: [RuleItem] = []
    var tasks: [TaskItem] = []
    var appointments: [AppointmentItem] = []
    var goals: [GoalItem] = []
    var goalLogs: [GoalLogItem] = []
    var contacts: [ContactItem] = []
    var documents: [DocumentItem] = []
    var chatMessages: [ChatItem] = []
    var papers: [PaperItem] = []
    var paperCheckNotes: [PaperCheckNoteItem] = []
    var photoTracks: [PhotoTrackItem] = []
    var photoEntries: [PhotoEntryItem] = []
    var checkIns: [CheckInItem] = []

    // MARK: - Items (names match the model properties)

    // each item below copies one model's stored fields, parent links as ids
    nonisolated struct PlanItem: Codable, Equatable, Sendable {
        var id: UUID
        var procedure: String
        var surgeryDate: Date?
        var dischargeDate: Date?
        var arrivalTime: Date?
        var hospitalName: String?
        var hospitalAddress: String?
        var sourceRaw: String
        var createdAt: Date
        var isSample: Bool
        // optional so older backups still open
        var checkInMinute: Int? = nil
        var checkInPromptDismissals: Int? = nil
        var checkInPromptLastDay: Int? = nil
        var hospitalWhereToGo: String? = nil
        var surgeryStartTime: Date? = nil
    }

    nonisolated struct MedicineItem: Codable, Equatable, Sendable {
        var id: UUID
        var planID: UUID?
        var name: String
        var alsoKnownAs: [String]
        var isGroup: Bool
        var actionRaw: String
        var startDay: Int?
        var endDay: Int?
        var strength: String
        var amount: String
        var timesOfDay: [Int]
        var foodNote: String
        var onlyIf: String
        var minHoursBetween: Int?
        var maxPerDay: Int?
        var lastGivenAt: Date?
        var hospitalDoseAt: Date? = nil
        var reason: String
        var exception: String
        var pillShape: String
        var pillColor: String
        var quote: String
        var quotePage: Int?
        var paperRaw: String
        var isConfirmed: Bool
        var putAwayAt: Date?
        var lastTakenAnswer: String?
        var lastTakenAt: Date?
        var createdAt: Date
        var paperID: UUID?
        // older backups have neither, they read as nil
        var changedByYouAt: Date? = nil
        var restartNote: String? = nil
    }

    nonisolated struct DoseLogItem: Codable, Equatable, Sendable {
        var medicineID: UUID?
        var scheduledFor: Date
        var loggedAt: Date
        var statusRaw: String
        // older backups have none
        var changedByYou: Bool? = nil
    }

    nonisolated struct RuleItem: Codable, Equatable, Sendable {
        var planID: UUID?
        var title: String
        var isAllowed: Bool
        var condition: String
        var startDay: Int?
        var endDay: Int?
        var quote: String
        var quotePage: Int?
        var paperRaw: String
        var paperID: UUID?
    }

    nonisolated struct TaskItem: Codable, Equatable, Sendable {
        var planID: UUID?
        var title: String
        var dueDay: Int?
        var isDone: Bool
        var doneAt: Date?
        var quote: String
        var quotePage: Int?
        var paperRaw: String
        var paperID: UUID?
    }

    nonisolated struct AppointmentItem: Codable, Equatable, Sendable {
        var planID: UUID?
        var title: String
        var date: Date
        var doctor: String
        var place: String
        var address: String
        var phone: String
        var purpose: String
        var bring: [String]
        var questions: [String]
        var isInCalendar: Bool
        var calendarEventID: String?
        var quote: String
        var quotePage: Int?
        var paperRaw: String
        var paperID: UUID?
    }

    nonisolated struct GoalItem: Codable, Equatable, Sendable {
        var id: UUID
        var planID: UUID?
        var title: String
        var detail: String
        var symbol: String
        var target: Int
        var reps: Int?
        var sets: Int?
        var seconds: Int?
        var timesPerDay: Int?
        var startDay: Int?
        var endDay: Int?
        var quote: String
    }

    nonisolated struct GoalLogItem: Codable, Equatable, Sendable {
        var goalID: UUID?
        var loggedAt: Date
    }

    nonisolated struct ContactItem: Codable, Equatable, Sendable {
        var planID: UUID?
        var name: String
        var detail: String
        var phone: String
        var roleRaw: String
        // older backups have none
        var email: String? = nil
    }

    nonisolated struct DocumentItem: Codable, Equatable, Sendable {
        var planID: UUID?
        var pageNumber: Int
        var paperRaw: String
        var redactedText: String
        var scannedAt: Date
        var paperID: UUID?
    }

    nonisolated struct ChatItem: Codable, Equatable, Sendable {
        var text: String
        var isFromPatient: Bool
        var createdAt: Date
        var quote: String
        var isWarning: Bool
        var quoteSource: String
        var callPhone: String
        var kindRaw: String
        var choices: [String]
    }

    nonisolated struct PaperItem: Codable, Equatable, Sendable {
        var id: UUID
        var planID: UUID?
        var kindRaw: String
        var sourceRaw: String
        var fieldRaw: String?
        var doctorName: String?
        var hospitalName: String?
        var otherKindText: String?
        var printedDate: Date?
        var addedAt: Date
    }

    nonisolated struct PaperCheckNoteItem: Codable, Equatable, Sendable {
        var findingKey: String
        var chosenPaperID: UUID?
        var officeSaid: String
        var whoSaid: String
        var date: Date
    }

    nonisolated struct PhotoTrackItem: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var createdAt: Date
    }

    nonisolated struct PhotoEntryItem: Codable, Equatable, Sendable {
        var id: UUID
        var trackID: UUID?
        var takenAt: Date
        var note: String
        var imageData: Data?
    }

    nonisolated struct CheckInItem: Codable, Equatable, Sendable {
        var day: Int
        var pain: Int
        var signs: [String]
        var note: String
        var createdAt: Date
        var editedAt: Date? = nil
    }
}

// MARK: - What the restore screen shows first

// what the restore screen shows before the patient restores
nonisolated struct BackupSummary: Equatable, Sendable {
    var procedure: String
    var surgeryDate: Date?
    var madeAt: Date
    var medicines: Int
    var papers: Int
    var photos: Int
    var checkIns: Int
    var doses: Int
}

extension BackupSnapshot {
    // the newest plan like the rest of the app shows
    nonisolated var summary: BackupSummary {
        let plan = plans.max { $0.createdAt < $1.createdAt }
        return BackupSummary(procedure: plan?.procedure ?? "", surgeryDate: plan?.surgeryDate, madeAt: madeAt,
                             medicines: medicines.count, papers: papers.count, photos: photoEntries.count,
                             checkIns: checkIns.count, doses: doseLogs.count)
    }
}

// MARK: - Models to snapshot

extension BackupSnapshot {

    private static func all<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    // copies every saved model, links become ids
    static func make(from context: ModelContext, now: Date = Date()) throws -> BackupSnapshot {
        var snapshot = BackupSnapshot(madeAt: now)

        // models without their own id get one just for this file
        var planIDs: [PersistentIdentifier: UUID] = [:]
        var medicineIDs: [PersistentIdentifier: UUID] = [:]
        var goalIDs: [PersistentIdentifier: UUID] = [:]
        // a stable id for a model so links can be rebuilt on restore
        func id(_ model: (some PersistentModel)?, in ids: inout [PersistentIdentifier: UUID]) -> UUID? {
            guard let model else { return nil }
            if let known = ids[model.persistentModelID] { return known }
            let fresh = UUID()
            ids[model.persistentModelID] = fresh
            return fresh
        }

        for plan in try all(CarePlan.self, in: context) {
            snapshot.plans.append(PlanItem(
                id: id(plan, in: &planIDs)!, procedure: plan.procedure, surgeryDate: plan.surgeryDate,
                dischargeDate: plan.dischargeDate, arrivalTime: plan.arrivalTime, hospitalName: plan.hospitalName,
                hospitalAddress: plan.hospitalAddress, sourceRaw: plan.sourceRaw, createdAt: plan.createdAt,
                isSample: plan.isSample, checkInMinute: plan.checkInMinute,
                checkInPromptDismissals: plan.checkInPromptDismissals, checkInPromptLastDay: plan.checkInPromptLastDay,
                hospitalWhereToGo: plan.hospitalWhereToGo, surgeryStartTime: plan.surgeryStartTime))
        }
        for medicine in try all(MedicineInstruction.self, in: context) {
            snapshot.medicines.append(MedicineItem(
                id: id(medicine, in: &medicineIDs)!, planID: id(medicine.plan, in: &planIDs),
                name: medicine.name, alsoKnownAs: medicine.alsoKnownAs, isGroup: medicine.isGroup,
                actionRaw: medicine.actionRaw, startDay: medicine.startDay, endDay: medicine.endDay,
                strength: medicine.strength, amount: medicine.amount, timesOfDay: medicine.timesOfDay,
                foodNote: medicine.foodNote, onlyIf: medicine.onlyIf, minHoursBetween: medicine.minHoursBetween,
                maxPerDay: medicine.maxPerDay, lastGivenAt: medicine.lastGivenAt,
                hospitalDoseAt: medicine.hospitalDoseAt, reason: medicine.reason,
                exception: medicine.exception, pillShape: medicine.pillShape, pillColor: medicine.pillColor,
                quote: medicine.quote, quotePage: medicine.quotePage, paperRaw: medicine.paperRaw,
                isConfirmed: medicine.isConfirmed, putAwayAt: medicine.putAwayAt,
                lastTakenAnswer: medicine.lastTakenAnswer, lastTakenAt: medicine.lastTakenAt,
                createdAt: medicine.createdAt, paperID: medicine.paperID,
                changedByYouAt: medicine.changedByYouAt, restartNote: medicine.restartNote))
        }
        for log in try all(DoseLog.self, in: context) {
            snapshot.doseLogs.append(DoseLogItem(
                medicineID: id(log.medicine, in: &medicineIDs), scheduledFor: log.scheduledFor,
                loggedAt: log.loggedAt, statusRaw: log.statusRaw, changedByYou: log.changedByYou ? true : nil))
        }
        for rule in try all(CareRule.self, in: context) {
            snapshot.rules.append(RuleItem(
                planID: id(rule.plan, in: &planIDs), title: rule.title, isAllowed: rule.isAllowed,
                condition: rule.condition, startDay: rule.startDay, endDay: rule.endDay, quote: rule.quote,
                quotePage: rule.quotePage, paperRaw: rule.paperRaw, paperID: rule.paperID))
        }
        for task in try all(CareTask.self, in: context) {
            snapshot.tasks.append(TaskItem(
                planID: id(task.plan, in: &planIDs), title: task.title, dueDay: task.dueDay, isDone: task.isDone,
                doneAt: task.doneAt, quote: task.quote, quotePage: task.quotePage, paperRaw: task.paperRaw,
                paperID: task.paperID))
        }
        for visit in try all(Appointment.self, in: context) {
            snapshot.appointments.append(AppointmentItem(
                planID: id(visit.plan, in: &planIDs), title: visit.title, date: visit.date, doctor: visit.doctor,
                place: visit.place, address: visit.address, phone: visit.phone, purpose: visit.purpose,
                bring: visit.bring, questions: visit.questions, isInCalendar: visit.isInCalendar, calendarEventID: visit.calendarEventID,
                quote: visit.quote, quotePage: visit.quotePage, paperRaw: visit.paperRaw, paperID: visit.paperID))
        }
        for goal in try all(DailyGoal.self, in: context) {
            snapshot.goals.append(GoalItem(
                id: id(goal, in: &goalIDs)!, planID: id(goal.plan, in: &planIDs), title: goal.title,
                detail: goal.detail, symbol: goal.symbol, target: goal.target, reps: goal.reps, sets: goal.sets,
                seconds: goal.seconds, timesPerDay: goal.timesPerDay, startDay: goal.startDay, endDay: goal.endDay,
                quote: goal.quote))
        }
        for log in try all(GoalLog.self, in: context) {
            snapshot.goalLogs.append(GoalLogItem(goalID: id(log.goal, in: &goalIDs), loggedAt: log.loggedAt))
        }
        for contact in try all(CareContact.self, in: context) {
            snapshot.contacts.append(ContactItem(
                planID: id(contact.plan, in: &planIDs), name: contact.name, detail: contact.detail,
                phone: contact.phone, roleRaw: contact.roleRaw, email: contact.email))
        }
        for page in try all(SourceDocument.self, in: context) {
            snapshot.documents.append(DocumentItem(
                planID: id(page.plan, in: &planIDs), pageNumber: page.pageNumber, paperRaw: page.paperRaw,
                redactedText: page.redactedText, scannedAt: page.scannedAt, paperID: page.paperID))
        }
        for message in try all(ChatMessage.self, in: context) {
            snapshot.chatMessages.append(ChatItem(
                text: message.text, isFromPatient: message.isFromPatient, createdAt: message.createdAt,
                quote: message.quote, isWarning: message.isWarning, quoteSource: message.quoteSource,
                callPhone: message.callPhone, kindRaw: message.kindRaw, choices: message.choices))
        }
        for paper in try all(Paper.self, in: context) {
            snapshot.papers.append(PaperItem(
                id: paper.id, planID: id(paper.plan, in: &planIDs), kindRaw: paper.kindRaw,
                sourceRaw: paper.sourceRaw, fieldRaw: paper.fieldRaw, doctorName: paper.doctorName,
                hospitalName: paper.hospitalName, otherKindText: paper.otherKindText,
                printedDate: paper.printedDate, addedAt: paper.addedAt))
        }
        for note in try all(PaperCheckNote.self, in: context) {
            snapshot.paperCheckNotes.append(PaperCheckNoteItem(
                findingKey: note.findingKey, chosenPaperID: note.chosenPaperID, officeSaid: note.officeSaid,
                whoSaid: note.whoSaid, date: note.date))
        }
        for track in try all(PhotoTrack.self, in: context) {
            snapshot.photoTracks.append(PhotoTrackItem(id: track.id, name: track.name, createdAt: track.createdAt))
        }
        for entry in try all(PhotoEntry.self, in: context) {
            snapshot.photoEntries.append(PhotoEntryItem(
                id: entry.id, trackID: entry.track?.id, takenAt: entry.takenAt, note: entry.note,
                imageData: entry.imageData))
        }
        for checkIn in try all(CheckIn.self, in: context) {
            snapshot.checkIns.append(CheckInItem(
                day: checkIn.day, pain: checkIn.pain, signs: checkIn.signs, note: checkIn.note,
                createdAt: checkIn.createdAt, editedAt: checkIn.editedAt))
        }
        return snapshot
    }
}

// MARK: - Restore

extension BackupSnapshot {

    // clears a model type before a restore writes the backup's copy
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) { context.delete(model) }
    }

    // replaces everything on this phone with the backup, all or nothing
    func restore(into context: ModelContext) throws {
        do {
            for type in RemedySchema.models { try Self.deleteAll(type, in: context) }
            insertAll(into: context)
            try context.save()
        } catch {
            // nothing half done, the old plan stays
            context.rollback()
            throw error
        }
    }

    // rebuilds every model, parents first so children can link to them
    private func insertAll(into context: ModelContext) {
        var plansByID: [UUID: CarePlan] = [:]
        for item in plans {
            let plan = CarePlan(procedure: item.procedure, surgeryDate: item.surgeryDate)
            plan.dischargeDate = item.dischargeDate
            plan.arrivalTime = item.arrivalTime
            plan.hospitalName = item.hospitalName
            plan.hospitalAddress = item.hospitalAddress
            plan.hospitalWhereToGo = item.hospitalWhereToGo
            plan.surgeryStartTime = item.surgeryStartTime
            plan.sourceRaw = item.sourceRaw
            plan.createdAt = item.createdAt
            plan.isSample = item.isSample
            plan.checkInMinute = item.checkInMinute
            plan.checkInPromptDismissals = item.checkInPromptDismissals ?? 0
            plan.checkInPromptLastDay = item.checkInPromptLastDay
            context.insert(plan)
            plansByID[item.id] = plan
        }
        func plan(_ id: UUID?) -> CarePlan? { id.flatMap { plansByID[$0] } }

        var medicinesByID: [UUID: MedicineInstruction] = [:]
        for item in medicines {
            let medicine = MedicineInstruction(name: item.name, action: .take, paper: .afterSurgery, quote: item.quote)
            medicine.alsoKnownAs = item.alsoKnownAs
            medicine.isGroup = item.isGroup
            medicine.actionRaw = item.actionRaw
            medicine.startDay = item.startDay
            medicine.endDay = item.endDay
            medicine.strength = item.strength
            medicine.amount = item.amount
            medicine.timesOfDay = item.timesOfDay
            medicine.foodNote = item.foodNote
            medicine.onlyIf = item.onlyIf
            medicine.minHoursBetween = item.minHoursBetween
            medicine.maxPerDay = item.maxPerDay
            medicine.lastGivenAt = item.lastGivenAt
            medicine.hospitalDoseAt = item.hospitalDoseAt
            medicine.reason = item.reason
            medicine.exception = item.exception
            medicine.pillShape = item.pillShape
            medicine.pillColor = item.pillColor
            medicine.quotePage = item.quotePage
            medicine.paperRaw = item.paperRaw
            medicine.isConfirmed = item.isConfirmed
            medicine.putAwayAt = item.putAwayAt
            medicine.lastTakenAnswer = item.lastTakenAnswer
            medicine.lastTakenAt = item.lastTakenAt
            medicine.createdAt = item.createdAt
            medicine.paperID = item.paperID
            medicine.changedByYouAt = item.changedByYouAt
            medicine.restartNote = item.restartNote
            context.insert(medicine)
            medicine.plan = plan(item.planID)
            medicinesByID[item.id] = medicine
        }
        for item in doseLogs {
            let log = DoseLog(scheduledFor: item.scheduledFor, status: .taken, loggedAt: item.loggedAt)
            log.statusRaw = item.statusRaw
            log.changedByYou = item.changedByYou ?? false
            context.insert(log)
            log.medicine = item.medicineID.flatMap { medicinesByID[$0] }
        }
        for item in rules {
            let rule = CareRule(title: item.title, isAllowed: item.isAllowed, paper: .afterSurgery, quote: item.quote)
            rule.condition = item.condition
            rule.startDay = item.startDay
            rule.endDay = item.endDay
            rule.quotePage = item.quotePage
            rule.paperRaw = item.paperRaw
            rule.paperID = item.paperID
            context.insert(rule)
            rule.plan = plan(item.planID)
        }
        for item in tasks {
            let task = CareTask(title: item.title, dueDay: item.dueDay, paper: .beforeSurgery, quote: item.quote)
            task.isDone = item.isDone
            task.doneAt = item.doneAt
            task.quotePage = item.quotePage
            task.paperRaw = item.paperRaw
            task.paperID = item.paperID
            context.insert(task)
            task.plan = plan(item.planID)
        }
        for item in appointments {
            let visit = Appointment(title: item.title, date: item.date, paper: .afterSurgery, quote: item.quote)
            visit.doctor = item.doctor
            visit.place = item.place
            visit.address = item.address
            visit.phone = item.phone
            visit.purpose = item.purpose
            visit.bring = item.bring
            visit.questions = item.questions
            visit.isInCalendar = item.isInCalendar
            visit.calendarEventID = item.calendarEventID
            visit.quotePage = item.quotePage
            visit.paperRaw = item.paperRaw
            visit.paperID = item.paperID
            context.insert(visit)
            visit.plan = plan(item.planID)
        }
        var goalsByID: [UUID: DailyGoal] = [:]
        for item in goals {
            let goal = DailyGoal(title: item.title, symbol: item.symbol, target: item.target)
            goal.detail = item.detail
            goal.reps = item.reps
            goal.sets = item.sets
            goal.seconds = item.seconds
            goal.timesPerDay = item.timesPerDay
            goal.startDay = item.startDay
            goal.endDay = item.endDay
            goal.quote = item.quote
            context.insert(goal)
            goal.plan = plan(item.planID)
            goalsByID[item.id] = goal
        }
        for item in goalLogs {
            let log = GoalLog(loggedAt: item.loggedAt)
            context.insert(log)
            log.goal = item.goalID.flatMap { goalsByID[$0] }
        }
        for item in contacts {
            let contact = CareContact(name: item.name, detail: item.detail, phone: item.phone, role: .careTeam)
            contact.roleRaw = item.roleRaw
            contact.email = item.email ?? ""
            context.insert(contact)
            contact.plan = plan(item.planID)
        }
        for item in documents {
            let page = SourceDocument(pageNumber: item.pageNumber, paper: .afterSurgery, redactedText: item.redactedText)
            page.paperRaw = item.paperRaw
            page.scannedAt = item.scannedAt
            page.paperID = item.paperID
            context.insert(page)
            page.plan = plan(item.planID)
        }
        for item in chatMessages {
            let message = ChatMessage(text: item.text, isFromPatient: item.isFromPatient, quote: item.quote, isWarning: item.isWarning)
            message.createdAt = item.createdAt
            message.quoteSource = item.quoteSource
            message.callPhone = item.callPhone
            message.kindRaw = item.kindRaw
            message.choices = item.choices
            context.insert(message)
        }
        for item in papers {
            let paper = Paper(kind: .beforeSurgery, source: .other, addedAt: item.addedAt)
            paper.id = item.id
            paper.kindRaw = item.kindRaw
            paper.sourceRaw = item.sourceRaw
            paper.fieldRaw = item.fieldRaw
            paper.doctorName = item.doctorName
            paper.hospitalName = item.hospitalName
            paper.otherKindText = item.otherKindText ?? ""
            paper.printedDate = item.printedDate
            context.insert(paper)
            paper.plan = plan(item.planID)
        }
        for item in paperCheckNotes {
            let note = PaperCheckNote(findingKey: item.findingKey, chosenPaperID: UUID(), officeSaid: item.officeSaid,
                                      whoSaid: item.whoSaid, date: item.date)
            note.chosenPaperID = item.chosenPaperID
            context.insert(note)
        }
        var tracksByID: [UUID: PhotoTrack] = [:]
        for item in photoTracks {
            let track = PhotoTrack(name: item.name)
            track.id = item.id
            track.createdAt = item.createdAt
            context.insert(track)
            tracksByID[item.id] = track
        }
        for item in photoEntries {
            let entry = PhotoEntry(imageData: Data(), takenAt: item.takenAt, note: item.note)
            entry.id = item.id
            entry.imageData = item.imageData
            context.insert(entry)
            entry.track = item.trackID.flatMap { tracksByID[$0] }
        }
        for item in checkIns {
            let checkIn = CheckIn(day: item.day, pain: item.pain, signs: item.signs, note: item.note)
            checkIn.createdAt = item.createdAt
            checkIn.editedAt = item.editedAt
            context.insert(checkIn)
        }
    }
}
