//
//  MissedDoseSheet.swift
//  Remedy
//
//  screen 21 one honest answer about a missed dose, never take it now
//

import SwiftUI

// did you take it, for a missed dose
struct MissedDoseSheet: View {
    let question: String
    let detail: String
    let onAnswer: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    // UI only the measured height so the sheet fits its words
    @State private var height: CGFloat = 360

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(question)
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(detail)
                        .font(.body)
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 12) {
                        PrimaryButton(title: TodayScreen.missedYes, symbol: "checkmark") { answer(true) }
                        SecondaryButton(title: TodayScreen.missedNo) { answer(false) }
                    }
                    .padding(.top, 8)
                    Text(TodayScreen.missedFooter)
                        .font(.footnote)
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.screenEdge + 4)
                .padding(.bottom, Spacing.sectionGap)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 + 80 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.screenBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.height(height), .large])
    }

    private func answer(_ took: Bool) {
        onAnswer(took)
        dismiss()
    }
}
