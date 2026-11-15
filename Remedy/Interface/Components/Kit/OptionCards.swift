//
//  OptionCards.swift
//  Remedy
//
//  small pieces shared by the first-run screens in both looks
//

import SwiftUI

// icon and words side by side, always centred together whatever the text size
struct CenteredLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 8) {
            configuration.icon
            configuration.title
        }
    }
}

extension View {
    // the bottom bar of a first-run screen, the same colour as the page with a hairline on top
    func onboardingBar() -> some View {
        background(.bar)
            .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - Option cards

// one choice in a list of choices
struct OptionItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    var subtitle = ""
    var isSelected: Bool? = nil     // nil is a plain action with a chevron
    var isEnabled = true
}

// the one way every first-run choice list looks: icon tile, title, a line under it, a radio mark or chevron
// one grouped card with hairlines in Classic and big separate cards in Simple
struct OptionCards: View {
    let items: [OptionItem]
    var isSimple = false
    let action: (String) -> Void

    var body: some View {
        if isSimple {
            VStack(spacing: Spacing.betweenCards) {
                ForEach(items) { item in
                    Button { action(item.id) } label: {
                        row(item)
                            .padding(18)
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                            .cardStyle()
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                    .strokeBorder(Color.accentInk, lineWidth: item.isSelected == true ? 2 : 0)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isEnabled)
                    .opacity(item.isEnabled ? 1 : 0.5)
                    .accessibilityAddTraits(item.isSelected == true ? .isSelected : [])
                }
            }
        } else {
            GroupedCard {
                ForEach(items) { item in
                    Button { action(item.id) } label: {
                        row(item)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, minHeight: Spacing.rowMin, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!item.isEnabled)
                    .opacity(item.isEnabled ? 1 : 0.5)
                    .accessibilityAddTraits(item.isSelected == true ? .isSelected : [])
                }
            }
        }
    }

    private func row(_ item: OptionItem) -> some View {
        HStack(spacing: isSimple ? 16 : 12) {
            ItemIconTile(kind: .goal(symbol: item.symbol), filled: item.isSelected == true,
                         size: isSimple ? 48 : Spacing.iconTile)
            VStack(alignment: .leading, spacing: isSimple ? 4 : 2) {
                Text(item.title)
                    .font(isSimple ? Font.title3.weight(.bold) : .body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(isSimple ? .body : .subheadline)
                        .foregroundStyle(Color.ink2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let selected = item.isSelected {
                RadioMark(isOn: selected, size: isSimple ? 32 : 26)
            } else {
                Image(systemName: "chevron.right")
                    .font((isSimple ? Font.title3 : .footnote).weight(.semibold))
                    .foregroundStyle(Color.ink3)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
