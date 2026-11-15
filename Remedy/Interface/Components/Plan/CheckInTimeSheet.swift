//
//  CheckInTimeSheet.swift
//  Remedy
//
//  the shared time picker for the daily check-in reminder, in both looks
//

import SwiftUI

// minutes after midnight and a date on any day
enum CheckInTimeDate {
    static func date(minute: Int) -> Date {
        CheckInTime.date(minute: minute, onDayOf: AppClock.now())
    }
    static func minute(of date: Date) -> Int {
        let parts = DayMath.calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

// the wheel on its own, used in setup too
struct CheckInTimeWheel: View {
    @Binding var minute: Int

    var body: some View {
        DatePicker("Check-in time",
                   selection: Binding(get: { CheckInTimeDate.date(minute: minute) },
                                      set: { minute = CheckInTimeDate.minute(of: $0) }),
                   displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .accessibilityLabel("Check-in time")
    }
}

// the check-in time picker
struct CheckInTimeSheet: View {
    var current: Int?
    var startsLater: Bool = false           // surgery is still ahead
    var isPrompt: Bool = false              // the one-time ask, not Settings
    var simple: Bool = false
    var onSave: (Int) -> Void
    var onNotNow: () -> Void = {}
    var onRemove: (() -> Void)? = nil

    @State private var minute = CheckInTime.defaultMinute

    private var title: String { "When should we remind you to check in?" }
    private var detail: String {
        if startsLater { return "Check-ins start the day after your surgery. Pick a time now and we will remind you then." }
        return isPrompt ? "A short check-in once a day helps you and your care team. You can change this in Settings."
                        : "We send a gentle reminder at this time each day."
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(simple ? .largeTitle.bold() : .title2.bold())
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(simple ? .title3 : .body)
                .foregroundStyle(Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            CheckInTimeWheel(minute: $minute)
                .frame(maxHeight: 180)
            Spacer(minLength: 0)
            Button("Save \(CheckInTime.text(minute: minute))") { onSave(minute) }
                .buttonStyle(RemedyButtonStyle())
                .accessibilityIdentifier("checkin-time-save")
            if let onRemove, current != nil {
                Button("Turn off the daily reminder", action: onRemove)
                    .font(.headline).foregroundStyle(Color.dangerInk)
                    .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
            }
            Button(isPrompt ? "Not now" : "Cancel", action: onNotNow)
                .font(.headline).foregroundStyle(Color.accentInk)
                .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                .accessibilityIdentifier("checkin-time-not-now")
        }
        .padding(simple ? Spacing.simpleEdge : Spacing.screenEdge)
        .padding(.top, 12)
        .remedyBackground()
        .presentationDetents([.large])
        .onAppear { minute = current ?? CheckInTime.defaultMinute }
    }
}
