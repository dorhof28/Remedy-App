//
//  FormCard.swift
//  Remedy
//
//  the one form look for every add and edit sheet in both looks:
//  grouped rows with the label left and the value right, a capsule picker, − value + steppers,
//  a 1.5pt danger border with a plain sentence for a problem, and the sheet's close and save
//

import SwiftUI

// MARK: - Section

// a form section whose rows use the app's card colour instead of plain white
struct FormCard<Content: View>: View {
    var header: String = ""
    var footer: String = ""
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            Group { content }
                .listRowBackground(Color.surface)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        } header: {
            if !header.isEmpty {
                Text(header)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink2)
                    .textCase(nil)
            }
        } footer: {
            if !footer.isEmpty { Text(footer).foregroundStyle(Color.ink2) }
        }
    }
}

// MARK: - Text row

// "Name   Tylenol (acetaminophen)", the label left and the typed value right, the problem under it
struct FormTextRow<Field: Hashable>: View {
    let label: String
    let prompt: String
    @Binding var text: String
    var focus: FocusState<Field?>.Binding
    let field: Field
    var problem: String? = nil
    var multiline = false
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var autocorrect = true
    var submitLabel: SubmitLabel = .next
    var onSubmit: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // at large text the label sits above so the value has the whole row
            let stacked = typeSize.isAccessibilitySize || multiline
            let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                                                      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
            layout {
                Text(label)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .fixedSize()
                field(text: $text)
                    .multilineTextAlignment(stacked ? .leading : .trailing)
                    .foregroundStyle(Color.ink)
            }
            .padding(.vertical, stacked ? 6 : 0)
            .frame(minHeight: FormMetrics.row)
            if let problem { FieldProblemText(text: problem) }
        }
        .listRowBackground(FieldProblemBackground(hasProblem: problem != nil))
    }

    @ViewBuilder
    private func field(text: Binding<String>) -> some View {
        let box = multiline ? AnyView(TextField(label, text: text, prompt: Text(prompt), axis: .vertical).lineLimit(1...4))
                            : AnyView(TextField(label, text: text, prompt: Text(prompt)))
        box
            .keyboardType(keyboard)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(!autocorrect)
            .focused(focus, equals: field)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
    }
}

// MARK: - Problem

// a warning symbol and a plain sentence in danger ink, never colour alone
struct FieldProblemText: View {
    let text: String
    var large = false

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(large ? .body.weight(.semibold) : .footnote.weight(.medium))
            .foregroundStyle(Color.dangerInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Problem: \(text)")
    }
}

// the row's surface with a 1.5pt danger edge when its field has a problem
struct FieldProblemBackground: View {
    let hasProblem: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        Color.surface
            .overlay {
                if hasProblem { shape.strokeBorder(Color.dangerInk, lineWidth: 1.5).padding(2) }
            }
    }
}

extension View {
    // a filled field's danger border, simple and standalone fields
    func fieldProblemBorder(_ hasProblem: Bool, radius: CGFloat = Radius.tile) -> some View {
        overlay {
            if hasProblem {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.dangerInk, lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Capsule picker

// the "What to do" control: one capsule with a white pill on the picked choice
// at accessibility sizes it turns into a list of radio rows so nothing is cut off
struct CapsulePicker<Value: Hashable>: View {
    let title: String
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var large = false

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    Button { pick(option) } label: {
                        HStack(spacing: 12) {
                            RadioMark(isOn: option == selection)
                            Text(label(option))
                                .font(large ? .title3.weight(.semibold) : .body.weight(.semibold))
                                .foregroundStyle(Color.ink)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: large ? FormMetrics.simpleRow : FormMetrics.row)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == selection ? .isSelected : [])
                }
            }
        } else {
            HStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    let isOn = option == selection
                    Button { pick(option) } label: {
                        Text(label(option))
                            .font((large ? Font.body : .subheadline).weight(.semibold))
                            .foregroundStyle(isOn ? Color.ink : Color.ink2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: large ? 44 : 32)
                            .background {
                                if isOn {
                                    Capsule().fill(Color.surface).shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(3)
            .remedyFieldBackground(shape: Capsule())
            .frame(minHeight: large ? FormMetrics.simpleRow : FormMetrics.row)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
        }
    }

    private func pick(_ option: Value) {
        Motion.perform(reduceMotion) { selection = option }
    }
}

// MARK: - Stepper

// "Most a day   ( −  4  + )", the value says Not set until the first tap
struct FormStepperRow: View {
    let title: String
    let valueText: String
    var canGoDown = true
    var canGoUp = true
    var large = false
    let step: (_ up: Bool) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                                                  : AnyLayout(HStackLayout(spacing: 10))
        layout {
            Text(title)
                .font(large ? .title3.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                stepButton(symbol: "minus", label: "Less", up: false, enabled: canGoDown)
                Text(valueText)
                    .font((large ? Font.title3 : .body).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
                    .frame(minWidth: large ? 64 : 44)
                    .contentTransition(.numericText())
                stepButton(symbol: "plus", label: "More", up: true, enabled: canGoUp)
            }
            .remedyFieldBackground(shape: Capsule())
            .fixedSize()
        }
        .frame(minHeight: large ? FormMetrics.simpleRow : FormMetrics.row)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(true)
            case .decrement: step(false)
            @unknown default: break
            }
        }
    }

    private func stepButton(symbol: String, label: String, up: Bool, enabled: Bool) -> some View {
        Button { step(up) } label: {
            Image(systemName: symbol)
                .font((large ? Font.title3 : .body).weight(.semibold))
                .foregroundStyle(enabled ? Color.ink : Color.ink3)
                .frame(width: large ? 52 : 44, height: large ? 44 : 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

// MARK: - Sheet chrome

extension View {
    // close circle on the left, inline title, tinted Save capsule on the right
    func formSheetChrome(title: String, saveTitle: String,
                         onClose: @escaping () -> Void, onSave: @escaping () -> Void) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseButton(action: onClose)
                SheetCapsuleButton(title: saveTitle, action: onSave)
            }
    }

    // the grouped form look every classic edit sheet shares
    func remedyFormStyle() -> some View {
        formStyle(.grouped)
            .listSectionSpacing(8)
            .environment(\.defaultMinListRowHeight, FormMetrics.row)
            .scrollContentBackground(.hidden)
            .remedyBackground()
            .scrollDismissesKeyboard(.interactively)
            .remedyFieldsInList()
    }
}
