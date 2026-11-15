//
//  PaperKit.swift
//  Remedy
//
//  the small pieces of first run and adding papers: sheet buttons, the privacy badge,
//  the hidden tag, connected steps and a radio mark, shared by both looks
//

import SwiftUI

// MARK: - Sheet chrome

// round close button on the left of a sheet's top bar
struct SheetCloseButton: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
            }
            .accessibilityLabel("Close")
        }
    }
}

// the tinted capsule on the right, Done or Save
struct SheetCapsuleButton: ToolbarContent {
    let title: String
    var placement: ToolbarItemPlacement = .confirmationAction
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: placement) {
            Button(action: action) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentInk)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Capsule().fill(Color.accentSoft))
            }
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

// MARK: - Privacy badge

// where the page goes, in two words and a symbol, never colour alone
struct PrivacyBadge: View {
    let place: PrivacyPlace

    var body: some View {
        StatusBadge(text: place.shortLabel, symbol: place.symbol, tone: place.tone)
            .fixedSize()
            .accessibilityLabel(place.label)
    }
}

// MARK: - Radio mark

// the round choice mark at the left of a single-choice row
struct RadioMark: View {
    let isOn: Bool
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(Color.accentFill)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(Color.onAccent)
            } else {
                Circle().strokeBorder(Color.ink3, lineWidth: 2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Page dots

// where we are in the setup questions
struct SetupDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.ink : Color.hairline)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

// MARK: - Hidden tag

// shared pieces for showing paper words
enum PaperKit {
    // a solid bar, the word inside is ink on ink so only voiceover says hidden
    static var hiddenTag: AttributedString {
        var tag = AttributedString("\u{00A0}\u{00A0}hidden\u{00A0}\u{00A0}")
        tag.swiftUI.foregroundColor = Color.ink
        tag.swiftUI.backgroundColor = Color.ink
        return tag
    }
}

