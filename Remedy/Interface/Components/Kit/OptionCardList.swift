//
//  OptionCardList.swift
//  Remedy
//
//  icon + title + one line choice rows, the same pattern as the "how to scan" sheet
//  one view for both looks: Classic is one list with lines, Simple is a big card for each choice
//

import SwiftUI

// one choice
struct OptionCardItem: Identifiable {
    let id: String
    var symbol: String = ""
    var title: String
    var subtitle: String = ""
    var isEnabled: Bool = true
    var tone: Tone = .info
    // draws a small theme preview instead of the symbol
    var swatch: (page: [Color], accent: Color)? = nil
}

// pick one: a tick on the chosen row, or leave selection nil to use it as a list of actions with chevrons
// Classic draws plain rows, put it inside a SettingsSection so the card is drawn once
struct OptionCardList<Below: View>: View {
    let items: [OptionCardItem]
    var selection: String? = nil
    // nil follows the look picked in Settings, Classic pages pass .classic so they never draw Simple cards
    var look: AppLook? = nil
    let onPick: (String) -> Void
    // extra content under the chosen row, like a key field
    @ViewBuilder let below: (OptionCardItem) -> Below

    @AppStorage(AppLook.storageKey) private var savedLook: AppLook = .simple

    private var hasBelow: Bool { Below.self != EmptyView.self }

    var body: some View {
        if (look ?? savedLook) == .simple {
            VStack(spacing: Spacing.betweenCards) {
                ForEach(items) { item in
                    let isChosen = selection == item.id
                    VStack(alignment: .leading, spacing: 10) {
                        row(item, isChosen: isChosen, isSimple: true)
                        if isChosen && hasBelow {
                            below(item)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 14)
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.groupFill)
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(isChosen ? Color.accentInk : Color.groupStroke, lineWidth: isChosen ? 3 : 1))
                    }
                    .opacity(item.isEnabled ? 1 : 0.55)
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
        } else {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    if item.id != items.first?.id { SettingsDivider(inset: 68) }
                    let isChosen = selection == item.id
                    VStack(alignment: .leading, spacing: 8) {
                        row(item, isChosen: isChosen, isSimple: false)
                        if isChosen && hasBelow {
                            below(item)
                                .padding(.leading, 68)
                                .padding(.trailing, 16)
                                .padding(.bottom, 10)
                        }
                    }
                    .opacity(item.isEnabled ? 1 : 0.55)
                }
            }
            .sensoryFeedback(.selection, trigger: selection)
        }
    }

    private func row(_ item: OptionCardItem, isChosen: Bool, isSimple: Bool) -> some View {
        Button {
            onPick(item.id)
        } label: {
            HStack(spacing: isSimple ? 16 : 12) {
                icon(item, size: isSimple ? 48 : 40)
                VStack(alignment: .leading, spacing: isSimple ? 4 : 2) {
                    Text(item.title)
                        .font(isSimple ? .title3.bold() : .body.weight(.medium))
                        .multilineTextAlignment(.leading)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(isSimple ? .body : .subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                trailing(isChosen: isChosen, isSimple: isSimple)
            }
            .padding(.horizontal, isSimple ? 18 : 16)
            .padding(.vertical, isSimple ? 14 : 8)
            .frame(maxWidth: .infinity, minHeight: isSimple ? 88 : 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(OptionRowButtonStyle())
        .disabled(!item.isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    @ViewBuilder
    private func icon(_ item: OptionCardItem, size: CGFloat) -> some View {
        if let swatch = item.swatch {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: swatch.page, startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(swatch.accent).frame(width: size * 0.42, height: size * 0.42)
                        .padding(size * 0.12)
                }
                .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Color.groupStroke, lineWidth: 1))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            IconTile(symbol: item.symbol, tone: item.tone, size: size)
        }
    }

    @ViewBuilder
    private func trailing(isChosen: Bool, isSimple: Bool) -> some View {
        if selection == nil {
            Chevron()
        } else {
            Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                .font(isSimple ? .title2 : .title3)
                .foregroundStyle(isChosen ? Color.accentInk : Color.inactive)
                .accessibilityHidden(true)
        }
    }
}

extension OptionCardList where Below == EmptyView {
    init(items: [OptionCardItem], selection: String? = nil, look: AppLook? = nil, onPick: @escaping (String) -> Void) {
        self.init(items: items, selection: selection, look: look, onPick: onPick, below: { _ in EmptyView() })
    }
}

// the row itself only dims when pressed, the section draws the card
private struct OptionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary)
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear)
    }
}

