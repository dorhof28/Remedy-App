//
//  SettingsParts.swift
//  Remedy
//
//  grouped settings cards: solid fill, clear outline, icon tiles and row lines
//  both looks use the surface, the classic look also uses the section and the rows
//

import SwiftUI

// MARK: - Surface

// solid card, the same one every grouped list uses
extension View {
    // the settings card look for one block
    func settingsCardStyle(radius: CGFloat = Radius.card) -> some View {
        cardStyle()
    }

    // padding and height every settings row shares
    func settingsRow() -> some View {
        padding(.horizontal, Spacing.insideCard)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMin, alignment: .leading)
    }
}

// MARK: - Page and section

// the scrolling page of grouped cards
struct SettingsScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sectionGap) {
                content
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 8)
            .padding(.bottom, Spacing.scrollBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .remedyBackground()
    }
}

// a small heading, a card of rows with lines between them, then a note
struct SettingsSection<Content: View, Header: View, Footer: View>: View {
    let content: Content
    let header: Header
    let footer: Footer

    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header, @ViewBuilder footer: () -> Footer) {
        self.content = content()
        self.header = header()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group(subviews: header) { parts in
                if !parts.isEmpty {
                    ForEach(parts) { part in part }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink2)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            Group(subviews: content) { rows in
                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            if row.id != rows.first?.id { SettingsDivider() }
                            row
                        }
                    }
                    .buttonStyle(SettingsRowButtonStyle())
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .settingsCardStyle()
                }
            }
            Group(subviews: footer) { parts in
                if !parts.isEmpty {
                    ForEach(parts) { part in part }
                        .font(.footnote)
                        .foregroundStyle(Color.ink2)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

extension SettingsSection where Header == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(content: content, header: { EmptyView() }, footer: footer)
    }
}

extension SettingsSection where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.init(content: content, header: header, footer: { EmptyView() })
    }
}

extension SettingsSection where Header == EmptyView, Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, header: { EmptyView() }, footer: { EmptyView() })
    }
}

// hairline between rows, starts after the icon tile
struct SettingsDivider: View {
    var inset: CGFloat = Spacing.insideCard + Spacing.iconTile + 12
    @Environment(\.displayScale) private var scale

    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: max(1 / scale, 0.5))
            .padding(.leading, inset)
            .accessibilityHidden(true)
    }
}

// buttons and links inside a section fill the whole row so the tap area is big
struct SettingsRowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.role == .destructive ? Color.dangerInk : Color.ink)
            .settingsRow()
            .background(configuration.isPressed ? Color.surface2 : Color.clear)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
    }
}

// MARK: - Rows

// icon tile, title and an optional line under it
struct SettingsLabel: View {
    let symbol: String
    let title: String
    var tone: Tone = .info
    var detail: String = ""

    var body: some View {
        HStack(spacing: 12) {
            ItemIconTile(kind: .custom(symbol: symbol, tone: tone))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}

// a switch row
struct SettingsToggleRow: View {
    let symbol: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsLabel(symbol: symbol, title: title)
        }
        .tint(Color.accentFill)
        .settingsRow()
    }
}

