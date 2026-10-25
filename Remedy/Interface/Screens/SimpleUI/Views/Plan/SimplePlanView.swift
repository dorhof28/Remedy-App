//
//  SimplePlanView.swift
//  Remedy
//
//  simple plan overview groups and visits
//

import SwiftUI
import SwiftData

struct SimplePlanView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = PlanViewModel(plan: plans.first, now: AppClock.now())
            SimpleScreen(title: "My plan") {
                ForEach(viewModel.simpleGroups) { group in
                    NavigationLink(value: SimpleRoute.planGroup(group.id)) {
                        SimpleGroupButton(group: group)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - One group, page by page

// one group of the plan
struct SimplePlanGroupView: View {
    let groupID: String

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = PlanViewModel(plan: plans.first, now: AppClock.now())
            let group = viewModel.simpleGroups.first { $0.id == groupID }
            SimpleScreen(title: group?.title ?? viewModel.title) {
                switch PlanViewModel.SimplePlanGroup(rawValue: groupID) {
                case .today:
                    let events = viewModel.events(onDay: viewModel.todayID)
                    if events.isEmpty {
                        Text(viewModel.emptyDayText(viewModel.todayID))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    SimplePagedList(items: events) { row in
                        SimpleRowCard(title: row.title, subtitle: row.detail, showsChevron: false) {
                            IconTile(symbol: row.symbol, tone: row.tone, size: 48)
                        }
                    }
                case .notYet:
                    ruleList(viewModel.notYetRows)
                case .ok:
                    ruleList(viewModel.okRows)
                case .comingUp:
                    ruleList(viewModel.comingUpRows)
                case .visits:
                    SimplePagedList(items: viewModel.visitRows) { row in
                        NavigationLink(value: row.appointment) {
                            SimpleRowCard(title: row.title, subtitle: row.detail, status: row.relative, tone: .info) {
                                DateTile(month: row.month, day: row.dayNumber, weekday: row.weekday, size: 56)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(row.spokenLabel)
                    }
                case .tasks:
                    SimplePagedList(items: viewModel.taskRows) { row in
                        Button {
                            Motion.perform(reduceMotion) { viewModel.toggle(row, in: context) }
                        } label: {
                            SimpleRowCard(title: row.title, subtitle: row.detail, showsChevron: false) {
                                Image(systemName: row.checkSymbol)
                                    .font(.system(size: 36))
                                    .foregroundStyle(row.checkTone.color)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(row.spokenLabel)
                        .accessibilityHint(row.spokenHint)
                        .sensoryFeedback(.success, trigger: row.isDone) { _, isDone in isDone }
                    }
                case nil:
                    EmptyView()
                }
            }
        }
    }

    private func ruleList(_ rows: [RuleRow]) -> some View {
        SimplePagedList(items: rows) { row in
            SimpleRowCard(title: row.title, subtitle: row.detail, status: row.headline, tone: row.tone, showsChevron: false) {
                IconTile(symbol: row.symbol, tone: row.tone, size: 48)
            }
            .accessibilityLabel(row.spokenLabel)
        }
    }
}

// MARK: - One visit (fits one screen; lists open on their own page)

// one visit
struct SimpleVisitView: View {
    let appointment: Appointment

    @Environment(\.modelContext) private var context
    // UI only is Apple's "New Event" screen open
    @State private var isAddingToCalendar = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = AppointmentDetailViewModel(appointment: appointment, now: AppClock.now())
            let parts = viewModel.dateParts
            SimpleScreen(title: viewModel.title) {
                HStack(spacing: 16) {
                    DateTile(month: parts.month, day: parts.day, weekday: parts.weekday, size: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.relativeText)
                            .font(.title2.bold())
                            .foregroundStyle(Color.remedyTeal)
                        Text(viewModel.subtitle)
                            .font(.title3)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                    }
                }
                .accessibilityElement(children: .combine)

                if viewModel.showsPurpose {
                    Text(viewModel.purpose)
                        .font(.title3)
                        .lineLimit(4)
                        .minimumScaleFactor(0.85)
                }

                HStack(spacing: 12) {
                    if let phoneURL = viewModel.phoneURL {
                        Link(destination: phoneURL) {
                            Label(viewModel.callTitle, systemImage: "phone.fill")
                        }
                        .buttonStyle(SimpleButtonStyle())
                    }
                    if let mapsURL = viewModel.mapsURL {
                        Link(destination: mapsURL) {
                            Label(viewModel.directionsTitle, systemImage: "map.fill")
                        }
                        .buttonStyle(SimpleButtonStyle(kind: .plain))
                    }
                }

                if viewModel.showsCalendarButton {
                    Button {
                        isAddingToCalendar = true
                    } label: {
                        Label(viewModel.calendarButtonTitle, systemImage: viewModel.calendarButtonSymbol)
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                    .disabled(!viewModel.canAddToCalendar)
                    .sheet(isPresented: $isAddingToCalendar) {
                        CalendarEventSheet(event: viewModel.calendarEvent()) { added in
                            if added { viewModel.markAddedToCalendar(in: context) }
                            isAddingToCalendar = false
                        }
                        .ignoresSafeArea()
                    }
                }

                if viewModel.showsBring {
                    NavigationLink {
                        SimpleListPage(title: viewModel.bringTitle, items: viewModel.bringItems, symbol: "checkmark.circle")
                    } label: {
                        SimpleGroupButton(group: SimpleGroup(id: "bring", title: viewModel.bringTitle, symbol: "bag.fill", tone: .info,
                                                             count: viewModel.bringItems.count,
                                                             preview: SimpleGroup.preview(viewModel.bringItems)))
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.showsQuestions {
                    NavigationLink {
                        SimpleListPage(title: viewModel.questionsTitle, items: viewModel.questions, symbol: "questionmark.circle")
                    } label: {
                        SimpleGroupButton(group: SimpleGroup(id: "questions", title: viewModel.questionsTitle, symbol: "text.bubble.fill",
                                                             tone: .info, count: viewModel.questions.count,
                                                             preview: SimpleGroup.preview(viewModel.questions, show: 1)))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - A plain list of sentences, page by page ("Bring", "Questions to ask")

// one page of rows
struct SimpleListPage: View {
    let title: String
    let items: [String]
    let symbol: String

    // strings aren't Identifiable so wrap them
    private struct Line: Identifiable {
        let id: Int
        let text: String
    }

    var body: some View {
        SimpleScreen(title: title) {
            SimplePagedList(items: items.enumerated().map { Line(id: $0.offset, text: $0.element) }, perPage: 5) { line in
                Label(line.text, systemImage: symbol)
                    .font(.title3)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            }
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimplePlanView() }
}
