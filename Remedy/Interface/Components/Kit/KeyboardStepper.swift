//
//  KeyboardStepper.swift
//  Remedy
//
//  a Next or Done button above the keyboard, so the number pad can move on too
//

import SwiftUI

// next and done above the keyboard, walking the form's fields in order
struct KeyboardStepper<Field: Hashable>: ViewModifier {
    var focus: FocusState<Field?>.Binding
    let title: (Field) -> String
    // moves focus on, or drops the keyboard after the last field
    let advance: (Field) -> Void

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(focus.wrappedValue.map(title) ?? "Done") {
                    if let field = focus.wrappedValue { advance(field) } else { focus.wrappedValue = nil }
                }
                .fontWeight(.semibold)
            }
        }
    }
}

extension View {
    func keyboardStepper<Field: Hashable>(focus: FocusState<Field?>.Binding,
                                          title: @escaping (Field) -> String,
                                          advance: @escaping (Field) -> Void) -> some View {
        modifier(KeyboardStepper(focus: focus, title: title, advance: advance))
    }
}
