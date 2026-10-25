//
//  PlanView.swift
//  Remedy
//
//  classic plan tab
//

import SwiftUI
import SwiftData

struct PlanView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only the day picked in the journey
    @State private var pickedDay: Int?
    // UI only is "Share with family" open
    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { _ in
                let viewModel = PlanViewModel(plan: plans.first, now: AppClock.now())
                content(viewModel)
                    .navigationTitle(viewModel.title)
                    .helpButtons()
                    .toolbar {
                        if viewModel.hasPlan {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    isSharing = true
                                } label: {
                                    Label("Share with family", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        if viewModel.showsTodayButton(picked: pickedDay ?? viewModel.todayID) {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(viewModel.todayButtonTitle) {
                                    Motion.perform(reduceMotion) { pickedDay = nil }
                                }
                            }
                        }
                    }
            }
            .background(Color.screenBackground)
            .sheet(isPresented: $isSharing) { FamilyShareView() }
            .navigationDestination(for: MedicineInstruction.self) { medicine in
                MedicineDetailView(medicine: medicine)
            }
            .navigationDestination(for: Appointment.self) { appointment in
                AppointmentDetailView(appointment: appointment)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: PlanViewModel) -> some View {
        if !viewModel.hasPlan {
            ContentUnavailableView(viewModel.emptyTitle, systemImage: "calendar",
                                   description: Text(viewModel.emptyDetail))
        } else {
            let picked = pickedDay ?? viewModel.todayID
            ScrollView {
                VStack(spacing: Spacing.betweenCards) {

                    // 1 the journey + the picked day
                    SectionCard(title: viewModel.journeyTitle, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                                collapsible: false, rememberAs: "plan.journey") {
                        DayPicker(days: viewModel.journeyDays, picked: picked) { day in
                            Motion.perform(reduceMotion) { pickedDay = day }
                        }
                        .padding(.vertical, 8)
                        Divider()
                        DayEventsList(title: viewModel.dayTitle(picked),
                                      subtitle: viewModel.daySubtitle(picked),
                                      rows: viewModel.events(onDay: picked),
                                      emptyText: viewModel.emptyDayText(picked))
                            .id(picked)
                            .transition(.opacity)
                    }

                    // 2 not yet
                    if viewModel.showsNotYet {
                        SectionCard(title: viewModel.notYetTitle, symbol: "hand.raised",
                                    detail: viewModel.notYetCountText, tone: .stop, rememberAs: "plan.notyet") {
                            RuleRowList(rows: viewModel.notYetRows)
                        }
                    }

                    // 3 visits
                    if viewModel.showsVisits {
                        SectionCard(title: viewModel.visitsTitle, symbol: "stethoscope",
                                    detail: viewModel.visitsCountText, rememberAs: "plan.visits") {
                            VisitRowList(rows: viewModel.visitRows)
                        }
                    }

                    // 4 to do
                    if viewModel.showsTasks {
                        SectionCard(title: viewModel.tasksTitle, symbol: "checklist",
                                    detail: viewModel.tasksCountText, rememberAs: "plan.tasks") {
                            ForEach(viewModel.taskRows) { row in
                                PlanTaskRow(row: row) {
                                    Motion.perform(reduceMotion) { viewModel.toggle(row, in: context) }
                                }
                            }
                        }
                    }

                    // 5 OK to do
                    if viewModel.showsOk {
                        SectionCard(title: viewModel.okTitle, symbol: "checkmark.circle",
                                    detail: viewModel.okCountText, tone: .good, rememberAs: "plan.ok") {
                            RuleRowList(rows: viewModel.okRows)
                        }
                    }

                    // 6 coming up
                    if viewModel.showsComingUp {
                        SectionCard(title: viewModel.comingUpTitle, symbol: "calendar",
                                    detail: viewModel.comingUpCountText, rememberAs: "plan.comingup") {
                            RuleRowList(rows: viewModel.comingUpRows)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, 8)
                .padding(.bottom, Spacing.scrollBottom)
            }
        }
    }
}

// MARK: - Day picker (swipe sideways)

// days you can swipe through
struct DayPicker: View {
    let days: [JourneyDay]
    let picked: Int
    let onPick: (Int) -> Void

    // lets the highlight glide from one day to the next
    @Namespace private var highlight

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(days) { day in
                        Button {
                            onPick(day.id)
                        } label: {
                            DayChip(day: day, isPicked: day.id == picked, highlight: highlight)
                        }
                        .buttonStyle(.plain)
                        .id(day.id)
                        .accessibilityLabel(day.spokenLabel)
                        .accessibilityAddTraits(day.id == picked ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear { proxy.scrollTo(picked, anchor: .center) }
            .onChange(of: picked) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }
}

// one day in the picker
struct DayChip: View {
    let day: JourneyDay
    let isPicked: Bool
    let highlight: Namespace.ID

    var body: some View {
        VStack(spacing: 4) {
            Text(day.weekday)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isPicked ? Color.white : .secondary)
            ZStack {
                if day.isSurgery {
                    Image(systemName: "star.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isPicked ? Color.white : Color.remedyTeal)
                    Text(day.dayNumber)
                        .font(.caption2.bold())
                        .foregroundStyle(isPicked ? Color.remedyTeal : Color.white)
                } else {
                    Text(day.dayNumber)
                        .font(.body.weight(day.isToday ? .bold : .medium))
                        .foregroundStyle(isPicked ? Color.white : (day.isPast ? .secondary : .primary))
                }
            }
            .frame(height: 24)
            // a dot under days where something happens
            Circle()
                .fill(day.markerKind?.tone.color ?? .clear)
                .frame(width: 5, height: 5)
                .opacity(isPicked ? 0 : 1)
        }
        .frame(width: 44, height: 64)
        .background {
            if isPicked {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.remedyTeal)
                    .matchedGeometryEffect(id: "picked", in: highlight)
            } else if day.isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.remedyTeal, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - What happens on the picked day

// what happens on the picked day
struct DayEventsList: View {
    let title: String
    let subtitle: String
    let rows: [PlanEventRow]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Spacing.rowVertical)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if rows.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            ForEach(rows) { row in
                if let medicine = row.medicine {
                    NavigationLink(value: medicine) { PlanEventRowView(row: row) }
                        .buttonStyle(.plain)
                } else if let appointment = row.appointment {
                    NavigationLink(value: appointment) { PlanEventRowView(row: row) }
                        .buttonStyle(.plain)
                } else {
                    PlanEventRowView(row: row)
                }
            }
        }
    }
}

// one event row
struct PlanEventRowView: View {
    let row: PlanEventRow

    var body: some View {
        IconRow(symbol: row.symbol, tone: row.tone, title: row.title,
                subtitle: row.detail, showsChevron: row.opensDetail)
    }
}

// MARK: - Rules

// rule rows
struct RuleRowList: View {
    let rows: [RuleRow]

    var body: some View {
        DividedList(items: rows, inset: 42) { row in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.symbol)
                    .font(.title3)
                    .foregroundStyle(row.tone.color)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.body.weight(.medium))
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(row.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(row.tone.color)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, Spacing.rowVertical)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.spokenLabel)
        }
    }
}

// MARK: - Visits

// visit rows
struct VisitRowList: View {
    let rows: [VisitRow]

    var body: some View {
        DividedList(items: rows, inset: 64) { row in
            NavigationLink(value: row.appointment) {
                HStack(spacing: 14) {
                    DateTile(month: row.month, day: row.dayNumber, weekday: row.weekday, size: 50)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.body.weight(.semibold))
                        Text(row.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(row.relative)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.remedyTeal)
                    }
                    Spacer(minLength: 0)
                    Chevron()
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.spokenLabel)
            .accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - To-dos

// one to do row
struct PlanTaskRow: View {
    let row: TaskRow
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: row.checkSymbol)
                    .font(.title2)
                    .foregroundStyle(row.checkTone.color)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .strikethrough(row.isDone)
                        .foregroundStyle(row.isDone ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                    Text(row.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.spokenLabel)
        .accessibilityHint(row.spokenHint)
        .sensoryFeedback(.success, trigger: row.isDone) { _, isDone in isDone }
    }
}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    PlanView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    PlanView()
}
