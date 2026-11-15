//
//  SimpleEditParts.swift
//  Remedy
//
//  the big versions of the shared form: filled fields, big rows, and Cancel and Save fixed at the bottom
//

import SwiftUI

// title, the fields, and Cancel and Save pinned at the bottom
struct SimpleEditScaffold<Content: View>: View {
    let title: String
    let saveTitle: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormMetrics.simpleGap) {
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .padding(.horizontal, Spacing.simpleEdge)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .remedyBackground()
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(SimpleButtonStyle(kind: .plain))
                Button(saveTitle, action: onSave)
                    .buttonStyle(SimpleButtonStyle())
            }
            .padding(.horizontal, Spacing.simpleEdge)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

// a small grey heading over a group of big rows
struct SimpleFormHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.ink2)
            .padding(.bottom, -6)
            .accessibilityAddTraits(.isHeader)
    }
}

// a filled field: label above, big value below, a danger edge and sentence for a problem
struct SimpleTextField<Field: Hashable>: View {
    let label: String
    let prompt: String
    @Binding var text: String
    var focus: FocusState<Field?>.Binding
    let field: Field
    var problem: String? = nil
    var submitLabel: SubmitLabel = .next
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var autocorrect = true
    var multiline = false
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Color.ink2)
                Group {
                    if multiline {
                        TextField(label, text: $text, prompt: Text(prompt), axis: .vertical).lineLimit(1...4)
                    } else {
                        TextField(label, text: $text, prompt: Text(prompt))
                    }
                }
                    .font(.title3)
                    .foregroundStyle(Color.ink)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(!autocorrect)
                    .focused(focus, equals: field)
                    .submitLabel(submitLabel)
                    .onSubmit(onSubmit)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .remedyFieldBackground(focused: focus.wrappedValue == field)
            .fieldProblemBorder(problem != nil)
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = field }
            .remedyFieldsInList()
            if let problem { FieldProblemText(text: problem, large: true) }
        }
    }
}

// a big white row holding one control
struct SimpleFormRow<Content: View>: View {
    var problem: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, minHeight: FormMetrics.simpleRow, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.surface))
                .fieldProblemBorder(problem != nil)
            if let problem { FieldProblemText(text: problem, large: true) }
        }
    }
}

// a big on or off row
struct SimpleToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        SimpleFormRow {
            Toggle(isOn: $isOn) {
                Text(title).font(.title3.weight(.semibold)).foregroundStyle(Color.ink)
            }
            .tint(Color.accentInk)
        }
    }
}

// one choice in a list of choices
struct SimpleChoiceRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RadioMark(isOn: isSelected, size: 30)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: FormMetrics.simpleRow, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(isSelected ? Color.accentSoft : Color.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// a big date or time row with the date pill on the right
struct SimpleDateRow: View {
    let title: String
    @Binding var date: Date
    var components: DatePickerComponents = .date

    var body: some View {
        SimpleFormRow {
            DatePillRow(title: title, date: $date, components: components, large: true)
        }
    }
}
