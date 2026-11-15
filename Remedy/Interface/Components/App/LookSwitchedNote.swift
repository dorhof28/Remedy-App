//
//  LookSwitchedNote.swift
//  Remedy
//
//  screen 84: the one-time note when big text switches the look to simple
//

import SwiftUI

// the words on the note after automatic switched to simple
enum LookNoteWords {
    static let text = "Your text is very large, so Remedy switched to the Simple look."
    static let useClassic = "Use Classic Instead"
    static let close = "Close"
}

// the one time note that simple was turned on, with a way back to classic
struct LookSwitchedNote: View {
    let onClassic: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text(LookNoteWords.text)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onClassic) {
                    Text(LookNoteWords.useClassic)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                    .font(.title2)
                    .foregroundStyle(Color.accentInk)
                    .frame(minHeight: Spacing.minTarget)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
                    .frame(width: Spacing.minTarget, height: Spacing.minTarget)
            }
            .accessibilityLabel(LookNoteWords.close)
        }
        .padding(Spacing.insideCard)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.bottom, 8)
    }
}
