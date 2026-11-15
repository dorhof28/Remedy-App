//
//  RemedyTextFieldStyle.swift
//  Remedy
//
//  one rounded look for every text field, set once at the app root
//  inside a Form or List row the field stays plain so there is no double box
//

import SwiftUI

// MARK: - Look numbers

// the size of remedy's text fields
enum RemedyField {
    static let radius: CGFloat = Radius.tile
    static let minHeight: CGFloat = FormMetrics.row
    static let padding: CGFloat = 10
    static let underlineWidth: CGFloat = 1.5
}

extension Color {
    // faint edge so the field still reads on a busy background
    static let fieldEdge = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.08) : UIColor(white: 0, alpha: 0.06)
    })
}

// true inside a list row, where the field drops its own box
private struct InListKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    // true inside a Form or List row, set by remedyFieldsInList
    var remedyFieldInList: Bool {
        get { self[InListKey.self] }
        set { self[InListKey.self] = newValue }
    }
}

extension View {
    // put on a Form or List so its fields stay plain
    func remedyFieldsInList() -> some View {
        environment(\.remedyFieldInList, true)
    }

    // the field look for custom inputs like search, pickers or a composer
    func remedyFieldBackground(focused: Bool = false, shape: some InsettableShape = RoundedRectangle(cornerRadius: RemedyField.radius, style: .continuous)) -> some View {
        modifier(FieldBackground(focused: focused, shape: shape))
    }
}

// MARK: - Box

// the rounded box and focus ring around a field
private struct RemedyFieldBox: ViewModifier {
    var minHeight: CGFloat
    @Environment(\.isFocused) private var isFocused
    @Environment(\.remedyFieldInList) private var inList

    func body(content: Content) -> some View {
        if inList {
            content.frame(minHeight: minHeight, alignment: .leading)
        } else {
            content
                .padding(RemedyField.padding)
                .frame(minHeight: minHeight, alignment: .leading)
                .remedyFieldBackground(focused: isFocused)
        }
    }
}

// no fill so the field takes the colour of whatever holds it, a faint edge, accent ring while typing
private struct FieldBackground<S: InsettableShape>: ViewModifier {
    let focused: Bool
    let shape: S

    func body(content: Content) -> some View {
        content
            .overlay(shape.strokeBorder(focused ? Color.accentInk : Color.fieldEdge,
                                        lineWidth: focused ? RemedyField.underlineWidth : 1))
            .contentShape(shape)
    }
}

// MARK: - Styles

// every text field in the app uses this
struct RemedyTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration.modifier(RemedyFieldBox(minHeight: RemedyField.minHeight))
    }
}

