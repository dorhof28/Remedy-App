//
//  ClassicTodayParts.swift
//  Remedy
//
//  classic today pieces: the today card, undo bar and hospital sheet
//

import SwiftUI

// shown after logging, stays until the patient taps Undo or closes it, never times out
struct UndoBar: View {
    let message: String
    let onUndo: () -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.title3)
                .foregroundStyle(Color.toneGreen)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Undo", action: onUndo)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.remedyTeal)
                .frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.ink2)
                        .frame(width: Spacing.minTarget, height: Spacing.minTarget)
                }
                .accessibilityLabel("Close")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.cardBackground).shadow(color: .black.opacity(0.08), radius: 10, y: 3))
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }
}

// the arrival time and hospital fields in a sheet
struct HospitalDetailsSheet: View {
    let plan: CarePlan?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plan {
                    Card { HospitalDayFields(plan: plan) }
                        .padding(.horizontal, Spacing.screenEdge)
                        .padding(.vertical, 8)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .remedyBackground()
            .navigationTitle("Surgery day details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .scrollDismissesKeyboard(.interactively)
    }
}

// a card that has the same look everywhere on Today
struct TodayCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.insideCard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
    }
}
