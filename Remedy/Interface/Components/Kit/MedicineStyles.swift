//
//  MedicineStyles.swift
//  Remedy
//
//  the date rows every edit form shares in both looks
//

import SwiftUI

// MARK: - Toggle and date in one row

// "Start day   [Fri, Nov 20]   (on)", off shows None instead of the date
// falls back to two lines only when the words are too big to fit
struct ToggleDateRow: View {
    let title: String
    @Binding var isOn: Bool
    @Binding var date: Date
    // big words for the simple look
    var large = false
    var noneText = "None"

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                label
                Spacer(minLength: 8)
                value
                toggle
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    label
                    Spacer(minLength: 8)
                    toggle
                }
                value
            }
        }
        .frame(minHeight: large ? FormMetrics.simpleRow : FormMetrics.row)
    }

    private var label: some View {
        Text(title)
            .font(large ? .title3.weight(.semibold) : .body.weight(.semibold))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .fixedSize()
    }

    // the date pill while on, None while off
    @ViewBuilder
    private var value: some View {
        if isOn {
            DatePicker(title, selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .fixedSize()
        } else {
            Text(noneText)
                .font(large ? .title3 : .body)
                .foregroundStyle(Color.ink2)
                .accessibilityHidden(true)
        }
    }

    private var toggle: some View {
        Toggle(title, isOn: $isOn)
            .labelsHidden()
            .tint(Color.accentInk)
            .fixedSize()
            .accessibilityValue(isOn ? Text(date, format: .dateTime.weekday(.wide).month().day()) : Text(noneText))
    }
}

// MARK: - Label and date pill

// "Day   [Fri, Nov 20]", the native compact picker as a pill on the right
struct DatePillRow: View {
    let title: String
    @Binding var date: Date
    var components: DatePickerComponents = .date
    var large = false

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(large ? .title3.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            DatePicker(title, selection: $date, displayedComponents: components)
                .datePickerStyle(.compact)
                .labelsHidden()
                .fixedSize()
        }
        .frame(minHeight: large ? FormMetrics.simpleRow : FormMetrics.row)
    }
}
