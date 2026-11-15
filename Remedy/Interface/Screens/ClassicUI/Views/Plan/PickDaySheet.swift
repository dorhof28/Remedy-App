//
//  PickDaySheet.swift
//  Remedy
//
//  classic pick a day (screen 41): the system calendar with surgery and visit days marked
//

import SwiftUI
import SwiftData

// a calendar to jump to any plan day
struct PickDaySheet: View {
    // the plan day picked, sent back so the caller opens it
    let onPick: (Int) -> Void

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss

    // UI only the date in the calendar
    @State private var date = AppClock.now()

    var body: some View {
        let screen = PickDayScreen(plan: plans.first, now: AppClock.now())
        NavigationStack {
            List {
                Section {
                    PlanCalendarPicker(selection: $date, surgery: screen.surgeryDay, visits: screen.visitDays)
                        .frame(minHeight: 360)
                    legend(screen)
                } footer: {
                    Text(screen.footer).font(.footnote).foregroundStyle(Color.ink2)
                }
            }
            .remedyList()
            .navigationTitle(screen.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(screen.cancelButton) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(screen.todayButton) { pick(AppClock.now(), screen) }
                }
            }
            .onChange(of: date) { _, new in pick(new, screen) }
        }
        .presentationDetents([.large])
    }

    private func legend(_ screen: PickDayScreen) -> some View {
        HStack(spacing: 16) {
            mark(screen.surgeryWord, color: Tone.stop.color)
            mark(screen.visitWord, color: Color.remedyTeal)
            mark(screen.todayWord, color: Color.accentFill)
        }
        .font(.subheadline)
        .foregroundStyle(Color.ink2)
    }

    private func mark(_ word: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(word)
        }
    }

    private func pick(_ picked: Date, _ screen: PickDayScreen) {
        guard let day = screen.day(of: picked) else { return }
        dismiss()
        onPick(day)
    }
}

// the system graphical calendar with decorations on surgery and visit days
struct PlanCalendarPicker: UIViewRepresentable {
    @Binding var selection: Date
    let surgery: Date?
    let visits: [Date]

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = DayMath.calendar
        view.delegate = context.coordinator
        let pick = UICalendarSelectionSingleDate(delegate: context.coordinator)
        pick.selectedDate = DayMath.calendar.dateComponents([.year, .month, .day], from: selection)
        view.selectionBehavior = pick
        view.tintColor = UIColor(Color.remedyTeal)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // marks plan days on apple's calendar view
    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: PlanCalendarPicker

        init(parent: PlanCalendarPicker) { self.parent = parent }

        // marks surgery and plan days on the calendar
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = DayMath.calendar.date(from: dateComponents) else { return nil }
            if let surgery = parent.surgery, DayMath.calendar.isDate(date, inSameDayAs: surgery) {
                return .default(color: UIColor(Tone.stop.color), size: .medium)
            }
            if parent.visits.contains(where: { DayMath.calendar.isDate(date, inSameDayAs: $0) }) {
                return .default(color: UIColor(Color.remedyTeal), size: .medium)
            }
            return nil
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let components = dateComponents, let date = DayMath.calendar.date(from: components) else { return }
            parent.selection = date
        }
    }
}
