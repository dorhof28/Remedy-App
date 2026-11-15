//
//  TodayScreen.swift
//  Remedy
//
//  today in the redesign: one loud card, alert rows above it, short lists under it
//  built from TodayViewModel so the rules stay where they are
//

import Foundation
import SwiftData

// where a row on Today goes or what it does
enum TodayTarget {
    case none
    case disagree(PaperCheckCardData)
    case missed(DoseListRow)
    case stopQuestion(StopQuestion)
    case medicinesTab
    case visit(Appointment)
    case todo(TaskRow)
    case goals
    case hospital
    case ready
    case anotherDay
    case addPapers
}

// one row in a Today list
struct TodayLine: Identifiable {
    let id: String
    var symbol: String? = nil
    var tone: Tone = .info
    let title: String
    var subtitle: String = ""
    var subtitleTone: Tone = .neutral
    var value: String = ""
    var isToDo = false          // a tick box instead of an icon
    var isChecked = false
    var target: TodayTarget = .none

    var opens: Bool {
        switch target {
        case .none, .todo: return false
        default: return true
        }
    }
}

// a titled group of rows, an empty title is a group with no header
struct TodayGroup: Identifiable {
    let id: String
    var title: String = ""
    let lines: [TodayLine]
}

// the loud card at the top
struct TodayTopCard {
    // what tapping the top card does
    enum Action {
        case takeDose(DoseListRow)
        case stopToday
        case directions(URL)
        case none
    }

    enum Style { case next, stop }

    let style: Style
    let eyebrow: String
    let symbol: String
    let title: String
    let text: String
    let buttonTitle: String
    let buttonSymbol: String?
    let showsNotNow: Bool
    let action: Action
    let id: String
}

// the classic today tab: top card, alerts and the rest of the day
struct TodayScreen {
    enum State { case noPlan, needsDate, finished, day }

    let today: TodayViewModel
    let state: State
    let subtitle: String
    let alerts: [TodayLine]
    // missed doses sit under the card, as on screen 19
    let afterCardAlerts: [TodayLine]
    let card: TodayTopCard?
    let groups: [TodayGroup]
    // 90, a yes to the stop question shows who to call until I Called
    let stopCalls: [StopQuestion]

    // MARK: - Words

    let title = "Today"
    let notNowButton = "Not Now"
    let emptyTitle = "No Papers Yet"
    let emptyText = "Add your hospital papers to see what to do each day."
    let addPapersButton = "Add Papers"
    let finishedTitle = "Your plan is done"
    let finishedText = "Every medicine and rule from your papers has ended."

    init(today: TodayViewModel, redCards: [PaperCheckCardData], questions: [StopQuestion], snoozed: Set<String>) {
        self.today = today
        stopCalls = questions.filter(\.showsCallCard)
        let now = today.now
        let date = DayMath.shortDate(now)

        switch today.layout {
        case .noPlan:
            state = .noPlan
        case .needsSurgeryDate:
            state = .needsDate
        case .afterSurgery where Self.isFinished(today):
            state = .finished
        default:
            state = .day
        }

        switch today.layout {
        case .beforeSurgery:
            let lead = today.day == -1 ? "Surgery tomorrow" : "Surgery in \(-today.day) days"
            subtitle = "\(lead) \u{00B7} \(DayMath.shortDate(today.surgeryDate))"
        case .surgeryDay:
            subtitle = "Surgery day \u{00B7} \(date)"
        case .afterSurgery:
            subtitle = "Day \(today.day) after surgery \u{00B7} \(date)"
        case .noPlan, .needsSurgeryDate:
            subtitle = ""
        }

        let doses = today.doseSections.flatMap(\.rows)
        let allAlerts = Self.alerts(redCards: redCards, missed: doses.filter { $0.state == .missed },
                                    questions: questions, today: today)
        alerts = allAlerts.filter { !$0.id.hasPrefix("missed") }
        afterCardAlerts = allAlerts.filter { $0.id.hasPrefix("missed") }
        card = state == .day ? Self.card(today, doses: doses, snoozed: snoozed) : nil
        groups = state == .finished ? Self.finishedGroups(today)
            : (state == .day ? Self.dayGroups(today, doses: doses, topID: card?.id) : [])
    }

    // MARK: - Finished

    // every medicine that can end, every rule and goal has ended, stops wait for the doctor
    private static func isFinished(_ today: TodayViewModel) -> Bool {
        guard let plan = today.plan else { return false }
        let medicines = today.medicines.filter { $0.action != .stop }.map(\.endDay)
        return PlanFinished.isFinished(endDays: medicines + plan.rules.map(\.endDay) + plan.goals.map(\.endDay),
                                       day: today.day)
    }

    // the plan is over: what is still stopped and who to ask
    private static func finishedGroups(_ today: TodayViewModel) -> [TodayGroup] {
        var lines: [TodayLine] = []
        let stopped = today.medicines.filter { $0.action == .stop && $0.endDay == nil }
        if !stopped.isEmpty {
            let names = TodayViewModel.uniqueNames(stopped.map { TodayViewModel.shortName(MedicineText.everydayName($0)) })
            lines.append(TodayLine(id: "stopped", symbol: "nosign", tone: .stop,
                                   title: "Still stopped: \(PlainText.list(names))",
                                   subtitle: "Ask before you start again", target: .medicinesTab))
        }
        if let visit = today.nextVisit(afterToday: false) {
            lines.append(TodayLine(id: "next-visit", symbol: "calendar", title: "Next visit",
                                   subtitle: "\(visit.title) \u{00B7} \(DayMath.shortDate(visit.date))", target: .visit(visit)))
        }
        let add = TodayLine(id: "add", symbol: "plus", title: "Add New Papers", subtitle: "After your next visit", target: .addPapers)
        return [TodayGroup(id: "left", lines: lines), TodayGroup(id: "add", lines: [add])].filter { !$0.lines.isEmpty }
    }

    // MARK: - Alerts

    // red cards, missed doses and stop questions, most urgent first
    private static func alerts(redCards: [PaperCheckCardData], missed: [DoseListRow],
                               questions: [StopQuestion], today: TodayViewModel) -> [TodayLine] {
        var lines = redCards.map { card in
            let ask = card.askByDate.map { "Ask before \(DayMath.shortDate($0))." } ?? "Ask today."
            return TodayLine(id: "disagree-\(card.id)", symbol: "exclamationmark.triangle", tone: .stop,
                             title: "Your papers disagree about \(card.finding.medicine)",
                             subtitle: "\(ask) Tap to see both.", target: .disagree(card))
        }
        lines += missed.map { row in
            TodayLine(id: "missed-\(row.id)", symbol: "exclamationmark.triangle", tone: .caution,
                      title: missedQuestion(row), subtitle: missedAdvice, target: .missed(row))
        }
        lines += questions.filter { $0.answer == nil }.map { question in
            TodayLine(id: "stopq-\(question.id.hashValue)", symbol: "nosign", tone: .caution,
                      title: question.shortQuestion, subtitle: question.tapToAnswer, target: .stopQuestion(question))
        }
        return lines
    }

    // MARK: - Missed dose question (21)

    static let missedAdvice = "Don\u{2019}t take an extra one to catch up."
    static let missedYes = "Yes, I Took It"
    static let missedNo = "No, I Missed It"
    static let missedFooter = "Took it at a different time? Choose Yes, then change the time."

    // "Did you take the 2 PM acetaminophen?"
    static func missedQuestion(_ row: DoseListRow) -> String {
        let time = DayMath.shortTimeText(DayMath.minuteOfDay(row.slot.scheduledFor))
        let name = TodayViewModel.shortName(MedicineText.everydayName(row.slot.medicine)).lowercased()
        return "Did you take the \(time) \(name)?"
    }

    // "Don't take an extra one to catch up. Your next one is at 10:00 PM."
    func missedDetail(_ row: DoseListRow) -> String {
        let next = today.doseSections.flatMap(\.rows).first {
            $0.slot.medicine == row.slot.medicine && $0.slot.scheduledFor > row.slot.scheduledFor && $0.state != .taken
        }
        guard let next else { return Self.missedAdvice }
        return "\(Self.missedAdvice) Your next one is at \(DayMath.timeText(of: next.slot.scheduledFor))."
    }

    // yes logs it at the time it was due, no logs it as skipped, never "take it now"
    func answerMissed(_ row: DoseListRow, took: Bool, in context: ModelContext) -> TodayUndo {
        let slot = row.slot
        let undo = DoseActions.log(slot.medicine, scheduledFor: slot.scheduledFor, as: took ? .taken : .skipped,
                                   now: took ? slot.scheduledFor : today.now, in: context)
        return TodayUndo(message: took ? "Logged \(row.name) at \(DayMath.timeText(of: slot.scheduledFor))"
                                       : "Marked \(row.name) as missed") { context in
            DoseActions.undo(undo, in: context)
        }
    }

    // MARK: - Not Now (20)

    static let remindButton = "Remind Me in 30 Minutes"
    static let skipButton = "I\u{2019}m Skipping This Dose"
    static let remindMinutes = 30
    // the done list opens in a sheet from one row
    static let doneGroupID = "done"
    static let doneTitle = "Done today"

    func notNowTitle(_ row: DoseListRow) -> String { "\(row.name), \(DayMath.timeText(of: row.slot.scheduledFor))" }

    func notNowMessage(_ row: DoseListRow) -> String {
        let reason = row.slot.medicine.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let why = reason.isEmpty ? "" : Self.sentence(reason) + " "
        return "\(why)If you skip it, don\u{2019}t take an extra one later."
    }

    // MARK: - The card

    // the one card on top: a stop today, a due dose or the next thing
    private static func card(_ today: TodayViewModel, doses: [DoseListRow], snoozed: Set<String>) -> TodayTopCard? {
        // a medicine to stop today comes first
        if today.layout == .beforeSurgery, !today.stopsStartingToday.isEmpty {
            let top = today.beforeTopCard
            if !top.isDone {
                let one = top.names.count == 1
                let text = top.detail.isEmpty
                    ? "Don\u{2019}t take \(one ? "it" : "them") from today on."
                    : "Don\u{2019}t take \(one ? "it" : "them") from today on. \(top.detail)"
                return TodayTopCard(style: .stop, eyebrow: "Stop today", symbol: "nosign",
                                 title: PlainText.list(top.names), text: text,
                                 buttonTitle: one ? "I\u{2019}ve Stopped It" : "I\u{2019}ve Stopped Them",
                                 buttonSymbol: nil, showsNotNow: false, action: .stopToday, id: "stop-today")
            }
        }
        // surgery day: where and when to arrive
        if today.layout == .surgeryDay, let plan = today.plan, let arrival = DayChecklist.arrival(for: plan), today.now < arrival {
            let name = plan.hospitalName.flatMap { $0.isEmpty ? nil : $0 } ?? "The hospital"
            let address = plan.hospitalAddress ?? ""
            let url = [plan.hospitalAddress, plan.hospitalName].compactMap { $0 }.first { !$0.isEmpty }.flatMap(DayMath.mapsURL)
            return TodayTopCard(style: .next, eyebrow: "Arrive at \(DayMath.timeText(of: arrival))", symbol: "building.2",
                             title: name, text: address,
                             buttonTitle: url == nil ? "" : "Get Directions", buttonSymbol: "mappin.and.ellipse",
                             showsNotNow: false, action: url.map { .directions($0) } ?? .none, id: "arrive")
        }
        // the dose due now, then the next one today
        let open = doses.filter { !snoozed.contains(cardID($0)) }
        if let due = open.first(where: { $0.state == .due }) {
            return doseCard(due, eyebrow: "Due now \u{00B7} \(DayMath.timeText(of: due.slot.scheduledFor))")
        }
        if let next = open.first(where: { $0.state == .upcoming }) {
            return doseCard(next, eyebrow: "Next \u{00B7} \(DayMath.timeText(of: next.slot.scheduledFor))")
        }
        return nil
    }

    static func cardID(_ row: DoseListRow) -> String { "dose-\(row.id)" }

    // the paper's reason as its own sentence, "Helps prevent blood clots."
    static func sentence(_ reason: String) -> String {
        let text = PlainText.upperFirst(reason)
        return text.hasSuffix(".") ? text : text + "."
    }

    private static func doseCard(_ row: DoseListRow, eyebrow: String) -> TodayTopCard {
        let reason = row.slot.medicine.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let how = row.how.isEmpty ? "" : "Take \(row.how)."
        let why = reason.isEmpty ? "" : sentence(reason)
        return TodayTopCard(style: .next, eyebrow: eyebrow, symbol: "clock", title: row.name,
                         text: [how, why].filter { !$0.isEmpty }.joined(separator: " "),
                         buttonTitle: "I Took It", buttonSymbol: "checkmark", showsNotNow: true,
                         action: .takeDose(row), id: cardID(row))
    }

    // "Logged Aspirin at 8:02 PM"
    func takenMessage(_ row: DoseListRow) -> String {
        "Logged \(TodayViewModel.shortName(row.name)) at \(DayMath.timeText(of: today.now))"
    }

    // MARK: - The lists

    // later today, to-dos and goals, without the card on top
    private static func dayGroups(_ today: TodayViewModel, doses: [DoseListRow], topID: String?) -> [TodayGroup] {
        var groups: [TodayGroup] = []
        let tasks = today.todayTasks
        let openTasks = tasks.filter { !$0.isDone }.map { row in
            TodayLine(id: "todo-\(row.id.hashValue)", title: row.title, subtitle: row.detail,
                      subtitleTone: row.detailTone, isToDo: true, target: .todo(row))
        }

        // stops already in effect
        var stoppedGroup: TodayGroup?
        let stopped = today.stopsAlreadyInEffect
        if !stopped.isEmpty, today.layout != .surgeryDay {
            let names = TodayViewModel.uniqueNames(stopped.map { MedicineText.everydayName($0) })
            let count = names.count == 1 ? "1 medicine" : "\(names.count) medicines"
            stoppedGroup = TodayGroup(id: "stopped", lines: [
                TodayLine(id: "stopped", symbol: "nosign", tone: .stop, title: "Still stopped: \(count)",
                          subtitle: PlainText.list(names), target: .medicinesTab),
            ])
        }
        // before surgery it sits right under the card, after surgery under the day's doses (screen 19)
        if let stoppedGroup, today.layout != .afterSurgery { groups.append(stoppedGroup) }

        switch today.layout {
        case .beforeSurgery:
            // every open before-surgery to-do, so the list is never empty days ahead (screen 14)
            var ready = today.readyTasks.map { row in
                TodayLine(id: "todo-\(row.id.hashValue)", title: row.title, subtitle: row.detail,
                          subtitleTone: row.detailTone, isToDo: true, target: .todo(row))
            }
            if let action = today.hospitalAction {
                ready.append(TodayLine(id: "hospital", symbol: "building.2", title: action.title,
                                       subtitle: action.detail, target: .hospital))
            }
            if today.showsReady {
                ready.append(TodayLine(id: "ready", symbol: "checklist", title: "Get ready for tomorrow",
                                       subtitle: "\(today.ready.checkCount) to check before bed", target: .ready))
            }
            groups.append(TodayGroup(id: "ready", title: "Get ready", lines: ready))
        case .surgeryDay:
            groups.append(TodayGroup(id: "morning", title: "Rules this morning", lines: morningRules(today)))
            groups.append(TodayGroup(id: "todo", title: "To do", lines: openTasks))
        case .afterSurgery:
            var later = doses.filter { $0.state == .upcoming && cardID($0) != topID }.map { row in
                TodayLine(id: "later-\(row.id)", symbol: "pills",
                          title: "\(DayMath.timeText(of: row.slot.scheduledFor)) \u{00B7} \(row.name)\(row.how.isEmpty ? "" : ", \(row.how)")")
            }
            later += openTasks
            let goals = today.goalTiles
            if !goals.isEmpty || today.showsCheckIn {
                let done = goals.reduce(0) { $0 + min($1.count, $1.target) }
                let total = goals.reduce(0) { $0 + $1.target }
                later.append(TodayLine(id: "goals", symbol: "figure.walk", title: "Walks and exercises",
                                       value: total > 0 ? "\(done) of \(total)" : "", target: .goals))
            }
            groups.append(TodayGroup(id: "later", title: "Later today", lines: later))
            if let stoppedGroup { groups.append(stoppedGroup) }
        case .noPlan, .needsSurgeryDate:
            break
        }

        // the papers' rules for today, before and after surgery
        if today.layout != .surgeryDay {
            let rules = today.rulesInEffectToday().map { rule in
                TodayLine(id: "rule-\(rule.id)", symbol: rule.row.symbol, tone: rule.row.tone,
                          title: rule.title, subtitle: rule.detail)
            }
            groups.append(TodayGroup(id: "rules", title: TodayViewModel.rulesTodayHeader, lines: rules))
        }

        // evenings only, what tomorrow needs tonight
        let tonight = today.tonight.map { row in
            TodayLine(id: "tonight-\(row.id)", symbol: row.kind == .stop ? "nosign" : "calendar",
                      tone: row.kind == .stop ? .caution : .info, title: row.title, subtitle: row.detail,
                      subtitleTone: row.detailTone, target: row.visit.map { .visit($0) } ?? .medicinesTab)
        }
        groups.append(TodayGroup(id: "tonight", title: today.tonightHeader, lines: tonight))

        // what is done, newest first
        var done = doses.filter { $0.state == .taken || $0.state == .skipped }
            .sorted { ($0.slot.log?.loggedAt ?? $0.slot.scheduledFor) > ($1.slot.log?.loggedAt ?? $1.slot.scheduledFor) }
            .map { row in
                let taken = row.state == .taken
                let at = row.slot.givenInHospital ? "In the hospital" : "Took it at \(DayMath.timeText(of: row.slot.log?.loggedAt ?? row.slot.scheduledFor))"
                return TodayLine(id: "done-\(row.id)", symbol: taken ? "checkmark.circle" : "minus.circle",
                                 tone: taken ? .good : .neutral, title: row.name, subtitle: taken ? at : "Skipped")
            }
        done += tasks.filter(\.isDone).map { row in
            TodayLine(id: "done-todo-\(row.id.hashValue)", title: row.title, subtitle: row.detail,
                      subtitleTone: .good, isToDo: true, isChecked: true, target: .todo(row))
        }
        groups.append(TodayGroup(id: Self.doneGroupID, title: Self.doneTitle, lines: done))

        groups.append(TodayGroup(id: "another", lines: [
            TodayLine(id: "another", symbol: "calendar", title: "See Another Day",
                      subtitle: "Yesterday, tomorrow or any date", target: .anotherDay),
        ]))
        return groups.filter { !$0.lines.isEmpty }
    }

    // surgery morning: eating, clear liquids and what not to take
    private static func morningRules(_ today: TodayViewModel) -> [TodayLine] {
        var lines: [TodayLine] = []
        if let plan = today.plan {
            let texts = plan.rules.flatMap { [$0.title, $0.quote] }
            let arrival = DayChecklist.arrival(for: plan)
            if let midnight = FastingTimes.foodStop(surgeryDate: today.surgeryDate, texts: texts) {
                lines.append(TodayLine(id: "food", symbol: "fork.knife", tone: .stop, title: "Nothing to eat",
                                       subtitle: "Since \(DayMath.timeText(of: midnight) == "12:00 AM" ? "midnight" : DayMath.timeText(of: midnight))"))
            }
            if let end = FastingTimes.clearLiquidsEnd(arrival: arrival, texts: texts) {
                let passed = today.now >= end
                lines.append(TodayLine(id: "liquids", symbol: "drop", tone: passed ? .stop : .caution,
                                       title: passed ? "Nothing to drink" : "Clear liquids until \(DayMath.timeText(of: end))",
                                       subtitle: passed ? "Since \(DayMath.timeText(of: end))" : "Then nothing."))
            }
        }
        let stopped = today.medicines.filter { $0.action == .stop && DoseSchedule.isActive($0, on: today.day) }
        if !stopped.isEmpty {
            let names = TodayViewModel.uniqueNames(stopped.map { TodayViewModel.shortName(MedicineText.everydayName($0)) })
            lines.append(TodayLine(id: "dont-take", symbol: "nosign", tone: .stop,
                                   title: "Don\u{2019}t take: \(PlainText.list(names))",
                                   subtitle: "Until your surgeon says it\u{2019}s OK", target: .medicinesTab))
        }
        lines += today.rulesInEffectToday().map { rule in
            TodayLine(id: "rule-\(rule.id)", symbol: rule.row.symbol, tone: rule.row.tone, title: rule.title, subtitle: rule.detail)
        }
        return lines
    }

    // MARK: - Snoozed cards (Remind Me in 30 Minutes)

    static let snoozeKey = "todaySnoozedUntil"

    // card ids hidden until their time passes
    static func snoozed(now: Date, defaults: UserDefaults = .standard) -> Set<String> {
        let saved = defaults.dictionary(forKey: snoozeKey) as? [String: Double] ?? [:]
        return Set(saved.filter { $0.value > now.timeIntervalSince1970 }.keys)
    }

    // not now hides a dose card for a while, expired ones are dropped
    static func snooze(_ id: String, now: Date, defaults: UserDefaults = .standard) {
        var saved = defaults.dictionary(forKey: snoozeKey) as? [String: Double] ?? [:]
        saved = saved.filter { $0.value > now.timeIntervalSince1970 }
        saved[id] = now.addingTimeInterval(TimeInterval(remindMinutes * 60)).timeIntervalSince1970
        defaults.set(saved, forKey: snoozeKey)
    }
}

// MARK: - Walks and exercises (23)

// the words on goals
enum GoalsWords {
    static let title = "Goals"
    static let doneOne = "Did One"
    static let footer = "Tap a goal to see how to do it, in your paper\u{2019}s words."
    static let checkInHeader = "Check-in"
    static let checkInTitle = "How do you feel today?"
    static let historyTitle = "Check-In History"
    static let historyDetail = "Pain chart and photos"
    static let noQuote = "Your paper doesn\u{2019}t say more about this one."

    // "1 of 3 today · 5 to 10 minutes"
    static func detail(_ tile: GoalTile) -> String {
        ["\(min(tile.count, tile.target)) of \(tile.target) today", tile.amountText].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

    // "1 minute · not done yet" or "Done · pain 4"
    static func checkInDetail(_ saved: CheckIn?) -> String {
        guard let saved else { return "1 minute \u{00B7} not done yet" }
        return "Done \u{00B7} pain \(saved.pain)"
    }
}

// MARK: - Papers disagree (16, 17)

// the words on the papers disagree pages
enum DisagreeWords {
    static let title = "Papers Disagree"
    static let toldMe = "The Office Told Me Which One"
    static let sheetTitle = "Which Is Right?"
    static let whoHeader = "Who told you?"
    static let someoneElse = "Someone else"
    static let notePrompt = "What did they say? (optional)"
    static let pickProblem = "Pick the paper that\u{2019}s right."

    // what the papers disagree about, then what remedy does until it is sorted out
    static func lead(_ card: PaperCheckCardData) -> String {
        [PaperCheckViewModel.sheetSubtitle, card.message.detail].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // 16 why remedy didn't pick (rule 6), then the last day both papers say the same
    static func whyNotPicked(_ card: PaperCheckCardData) -> String {
        let finding = card.finding
        guard card.isRed, !finding.isCircle, !finding.isResolved, finding.items.count >= 2 else { return "" }
        let older = PaperCheck.facts(finding.older), newer = PaperCheck.facts(finding.newer)
        let outcome = NewerPaperRule.decide(older, newer)
        var lines = [NewerPaperRule.explanation(outcome, newerGiver: newer.giver,
                                                daysApart: NewerPaperRule.daysApart(older, newer))]
        if finding.kind == .differentStopDay, let agreeUntil = card.askByDate {
            lines.append("Both agree you can take it as usual through \(DayMath.shortDate(agreeUntil)).")
        }
        return lines.joined(separator: " ")
    }

    // "Surgery team · Oct 28"
    static func byline(_ quote: CardQuote) -> String {
        let who = quote.role.isEmpty ? quote.doctor : PlainText.upperFirst(quote.role)
        return quote.dateText == "no date" ? "\(who) \u{00B7} no date" : "\(who) \u{00B7} \(quote.dateText)"
    }

    // "For Apixaban (Eliquis), which paper is right?"
    static func question(_ card: PaperCheckCardData) -> String { "For \(card.finding.medicine), \(PlainText.lowerFirst(card.resolveQuestion))" }

    // "Dr. Rao's paper · Oct 28"
    static func paperLine(_ quote: CardQuote) -> String {
        let who = quote.role.isEmpty ? "\(quote.doctor)\u{2019}s paper" : "\(PlainText.upperFirst(quote.role)) paper"
        return "\(who) \u{00B7} \(quote.dateText)"
    }

    // "Surgeon's office", one per paper, then someone else
    static func offices(_ card: PaperCheckCardData) -> [String] {
        var seen: [String] = []
        for quote in card.quotes {
            let name = quote.role.isEmpty ? "\(quote.doctor)\u{2019}s office" : "\(PlainText.upperFirst(quote.role))\u{2019}s office"
            if !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    // what is written on the medicine
    static func footer(who: String, now: Date) -> String {
        let name = who.isEmpty ? "the office" : PlainText.lowerFirst(who)
        return "Remedy notes \u{201C}Confirmed by \(name), \(DayMath.shortDate(now))\u{201D} on the medicine. Both papers stay in its history."
    }
}
