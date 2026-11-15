//
//  ThemePicker.swift
//  Remedy
//
//  the five themes as cards, each with its own colours, in a two column grid
//

import SwiftUI

// picks the app's color theme
struct ThemePicker: View {
    @Binding var theme: AppTheme
    // Simple gets bigger cards and text
    var look: AppLook? = nil
    @Environment(\.colorScheme) private var scheme
    @AppStorage(AppLook.storageKey) private var savedLook: AppLook = .classic

    private var isSimple: Bool { (look ?? savedLook) == .simple }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.betweenCards), GridItem(.flexible())],
                  spacing: Spacing.betweenCards) {
            ForEach(AppTheme.allCases) { option in
                card(option)
            }
        }
        .sensoryFeedback(.selection, trigger: theme)
    }

    private func card(_ option: AppTheme) -> some View {
        let isPicked = option == theme
        // always dark themes stay dark, the others follow the phone
        let dark = option.colorScheme.map { $0 == .dark } ?? (scheme == .dark)
        let p = option.palette(dark: dark)
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return Button {
            theme = option
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    Color(p.accentFill)
                    Color(p.second)
                    Color(p.bg)
                    Color(p.ink)
                }
                .frame(height: isSimple ? 56 : 44)
                .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(option.title)
                            .font((isSimple ? Font.title3 : .body).weight(.semibold))
                            .foregroundStyle(Color.ink)
                        Spacer(minLength: 0)
                        if isPicked {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentInk)
                        }
                    }
                    Text(option.detail)
                        .font(isSimple ? .body : .footnote)
                        .foregroundStyle(Color.ink2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .overlay(shape.strokeBorder(Color.accentFill, lineWidth: isPicked ? 2.5 : 0))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}

extension AppTheme {
    // one plain line under the name
    var detail: String {
        switch self {
        case .remedy: return "Mint and pink, from the app icon"
        case .ocean: return "Sky blue and aqua"
        case .sunset: return "Coral and peach"
        case .native: return "Apple\u{2019}s own colours, like Settings"
        case .graphite: return "Quiet grey"
        }
    }
}
