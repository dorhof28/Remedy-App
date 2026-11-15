//
//  ListKit.swift
//  Remedy
//
//  the shared pieces of the redesign: list rows, the next card, paper quotes, buttons, chips, hero messages
//

import SwiftUI

// MARK: - Row icon

// symbol on a soft rounded square, tinted by its tone
struct RowIcon: View {
    let symbol: String
    var tone: Tone = .info

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.medium))
            .imageScale(.small)
            .foregroundStyle(tone == .neutral ? Color.ink2 : tone.color)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(tone.soft))
            .accessibilityHidden(true)
    }
}

// MARK: - List row

// icon, title, one detail line, then a value, a button or a chevron
// at accessibility sizes the trailing part moves under the text
struct ListRow<Trailing: View>: View {
    var symbol: String? = nil
    var tone: Tone = .info
    let title: String
    var subtitle: String = ""
    var subtitleTone: Tone = .neutral
    var value: String = ""
    var showsChevron = false
    @ViewBuilder var trailing: Trailing

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                             : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            HStack(alignment: .center, spacing: 14) {
                if let symbol { RowIcon(symbol: symbol, tone: tone) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(subtitleTone == .neutral ? Color.ink2 : subtitleTone.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                if !value.isEmpty {
                    Text(value)
                        .font(.body)
                        .monospacedDigit()
                        .foregroundStyle(Color.ink2)
                }
                trailing
                if showsChevron { Chevron() }
            }
        }
        .frame(minHeight: Spacing.minTarget)
        .contentShape(Rectangle())
    }
}

extension ListRow where Trailing == EmptyView {
    init(symbol: String? = nil, tone: Tone = .info, title: String, subtitle: String = "",
         subtitleTone: Tone = .neutral, value: String = "", showsChevron: Bool = false) {
        self.init(symbol: symbol, tone: tone, title: title, subtitle: subtitle, subtitleTone: subtitleTone,
                  value: value, showsChevron: showsChevron) { EmptyView() }
    }
}

// MARK: - Section header

// a bold header above a list group, sentence case, never shouted in capitals
struct ListSectionHeader: View {
    let title: String
    var trailing: String = ""
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let action, !trailing.isEmpty {
                Button(trailing, action: action)
                    .font(.body)
                    .foregroundStyle(Color.accentInk)
                    .frame(minHeight: Spacing.minTarget)
            }
        }
        .textCase(nil)
        .padding(.leading, -12)
    }
}

extension View {
    // a list group tinted for its tone, like a caution or stop alert row
    func toneRow(_ tone: Tone) -> some View {
        listRowBackground(tone.soft)
    }

    // list style shared by every redesigned list screen
    func remedyList() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.screenBackground)
            .listSectionSpacing(.compact)
            // the row is the box, so fields inside a list draw no box of their own
            .textFieldStyle(.plain)
    }

    // a row with no card behind it, for cards and buttons drawn inside a list
    func plainListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }
}

// MARK: - Next card

// the loud card at the top: teal outline for next, a tint for stop, caution or good
struct ActionCard<Actions: View>: View {
    // how a card looks: next up, plain card, stop, caution or good
    enum Style { case next, card, stop, caution, good, plain }

    let style: Style
    var eyebrow: String = ""
    var eyebrowSymbol: String? = nil
    var title: String = ""
    var subtitle: String = ""
    var text: String = ""
    var spokenLabel: String? = nil
    // a card in another tone's colour words, like a rule's do or don't
    var eyebrowTone: Tone? = nil
    @ViewBuilder var actions: Actions

    private var tone: Tone {
        if let eyebrowTone { return eyebrowTone }
        switch style {
        case .next, .card: return .info
        case .stop: return .stop
        case .caution: return .caution
        case .good: return .good
        case .plain: return .neutral
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                if !eyebrow.isEmpty {
                    Group {
                        if let eyebrowSymbol {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: eyebrowSymbol).accessibilityHidden(true)
                                Text(eyebrow).fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            Text(eyebrow)
                        }
                    }
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    // the darker teal so small words pass contrast
                    .foregroundStyle(tone == .neutral ? Color.ink2 : (tone == .info ? Color.accentInk : tone.color))
                }
                if !title.isEmpty {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(spokenLabel ?? [eyebrow, title, subtitle, text].filter { !$0.isEmpty }.joined(separator: ", "))
            actions
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.insideCard + 4)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(fill))
        .overlay {
            if style == .next {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.remedyTeal, lineWidth: 2)
            }
        }
    }

    private var fill: Color {
        switch style {
        case .next, .card, .plain: return .cardBackground
        case .stop: return .dangerSoft
        case .caution: return .cautionSoft
        case .good: return .goodSoft
        }
    }
}

extension ActionCard where Actions == EmptyView {
    init(style: Style, eyebrow: String = "", eyebrowSymbol: String? = nil, title: String = "", subtitle: String = "",
         text: String = "", spokenLabel: String? = nil, eyebrowTone: Tone? = nil) {
        self.init(style: style, eyebrow: eyebrow, eyebrowSymbol: eyebrowSymbol, title: title, subtitle: subtitle,
                  text: text, spokenLabel: spokenLabel, eyebrowTone: eyebrowTone) { EmptyView() }
    }
}

// MARK: - Fact rows

// a label on the left and its value in bold, lined up, stacked at accessibility sizes
struct FactRows: View {
    let rows: [InfoRow]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 2) { label(row); value(row) }
                        .accessibilityElement(children: .combine)
                }
            }
        } else {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach(rows) { row in
                    GridRow { label(row); value(row) }
                        .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func label(_ row: InfoRow) -> some View {
        Text(row.label).font(.body).foregroundStyle(Color.ink2)
    }

    private func value(_ row: InfoRow) -> some View {
        Text(row.value).font(.body.weight(.semibold)).foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Buttons

// a filled capsule that dims while pressed, the label colour is always ours
struct CapsuleFillStyle: ButtonStyle {
    let fill: Color
    let text: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(text)
            .padding(.horizontal, Spacing.insideCard)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.4))
    }
}

// the one loud action on a screen, teal capsule, white text (black in dark mode)
struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Spacing.buttonHeight)
        }
        .buttonStyle(CapsuleFillStyle(fill: .accentFill, text: .onAccent))
    }

    @ViewBuilder private var label: some View {
        if let symbol { Label(title, systemImage: symbol) } else { Text(title) }
    }
}

// a grey capsule with label-colour text and a teal icon
struct SecondaryButton: View {
    let title: String
    var symbol: String? = nil
    var symbolTone: Tone = .info
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(symbolTone.color)
                        .accessibilityHidden(true)
                }
                Text(title).foregroundStyle(Color.ink)
            }
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: Spacing.buttonHeight)
        }
        .buttonStyle(CapsuleFillStyle(fill: .surface2, text: .ink))
    }
}

// red call 911, white text, never needs unlocking
struct EmergencyCallButton: View {
    var title: String = "Call 911"

    var body: some View {
        if let url = URL(string: "tel://911") {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill").accessibilityHidden(true)
                    Text(title).fixedSize(horizontal: false, vertical: true)
                }
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: Spacing.buttonHeight)
                    .background(Capsule().fill(Color.emergencyRed))
            }
            .accessibilityHint("Calls emergency services")
        }
    }
}

// a grey call button that opens the phone app
struct PhoneButton: View {
    let title: String
    let url: URL?

    var body: some View {
        if let url {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill").foregroundStyle(Color.remedyTeal).accessibilityHidden(true)
                    Text(title).foregroundStyle(Color.ink)
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Spacing.buttonHeight)
            }
            .buttonStyle(CapsuleFillStyle(fill: .surface2, text: .ink))
        }
    }
}

// MARK: - Paper quote

// the paper's own words with a mint bar: where it is from, the quote, then plain words
struct PaperQuote: View {
    let source: String
    let quote: String
    var plain: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
                Text(source)
                    .font(.footnote)
                    .foregroundStyle(Color.ink2)
                Text(quote)
                    .font(.body)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !plain.isEmpty {
                    Text(plain)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.insideCard)
        .background(Color.cardBackground)
        // the mint bar on the left is decoration
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.logoMint).frame(width: 5).accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Disclaimer

// the medical disclaimer in a quiet box
struct DisclaimerBox: View {
    var text: String = "Remedy helps you read your papers. It doesn't replace your doctor."

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.subheadline)
            .foregroundStyle(Color.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.insideCard)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.cardBackground))
    }
}

// MARK: - Hero message

// a symbol in a tile, a title and a few words, for pre-screens, errors and finished states
struct HeroMessage: View {
    let symbol: String
    var tone: Tone = .info
    let title: String
    var text: String = ""

    @ScaledMetric(relativeTo: .largeTitle) private var tile: CGFloat = 112

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: tile * 0.42, weight: .medium))
                .foregroundStyle(tone == .neutral ? Color.ink2 : tone.color)
                .frame(width: tile, height: tile)
                .background(RoundedRectangle(cornerRadius: Radius.card + 8, style: .continuous).fill(Color.cardBackground))
                .accessibilityHidden(true)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// a whole screen made of a hero message and its buttons pinned at the bottom
struct HeroScreen<Buttons: View>: View {
    let symbol: String
    var tone: Tone = .info
    let title: String
    var text: String = ""
    @ViewBuilder var buttons: Buttons

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionGap) {
                HeroMessage(symbol: symbol, tone: tone, title: title, text: text)
                // at accessibility sizes the buttons end the page instead of covering it
                if typeSize.isAccessibilitySize { VStack(spacing: 12) { buttons } }
            }
            .padding(.horizontal, Spacing.screenEdge + 8)
            .padding(.vertical, Spacing.sectionGap)
        }
        // centred when it fits, scrolls from the top when it doesnt
        .defaultScrollAnchor(.center, for: .alignment)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize {
                VStack(spacing: 12) { buttons }
                    .padding(.horizontal, Spacing.screenEdge + 8)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.screenBackground)
    }
}

// MARK: - Filter chips

// filter tiles in one row, all the same width: icon and count, the word under them
// at accessibility sizes they wrap like FilterChips so no word is cut
struct EqualFilterTiles<ID: Hashable>: View {
    struct Tile: Identifiable {
        let id: ID
        let word: String
        let count: Int
        var symbol: String? = nil
        var tone: Tone = .info
    }

    let tiles: [Tile]
    @Binding var selection: ID

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            FlowLayout(spacing: 10) { ForEach(tiles) { tile($0) } }
        } else {
            HStack(spacing: 6) {
                ForEach(tiles) { tile($0).frame(maxWidth: .infinity) }
            }
        }
    }

    private func tile(_ tile: Tile) -> some View {
        let picked = tile.id == selection
        return Button { selection = tile.id } label: {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    if let symbol = tile.symbol {
                        Image(systemName: symbol)
                            .foregroundStyle(picked ? Color.onAccent : (tile.tone == .neutral ? Color.ink2 : tile.tone.color))
                    }
                    Text("\(tile.count)")
                        .monospacedDigit()
                }
                .font(.headline)
                Text(tile.word)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(picked ? Color.onAccent : Color.ink)
            .padding(.horizontal, 3)
            .padding(.vertical, 8)
            .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity, minHeight: Spacing.minTarget)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(picked ? Color.accentFill : Color.cardBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tile.word), \(tile.count)")
        .accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
    }
}

// lays children out in rows, wrapping to the next line when a row is full
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    // true puts each row in the middle instead of on the left
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(width: width, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            let shift = centered ? max(0, (bounds.width - row.width) / 2) : 0
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + shift + item.x, y: bounds.minY + row.y),
                                           proposal: ProposedViewSize(item.size))
            }
        }
    }

    // one tag and where it sits
    private struct Item { let index: Int; let x: CGFloat; let size: CGSize }
    // one row of tags
    private struct Row { var items: [Item] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    // wraps tags into rows that fit the width
    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        var y: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let x = row.items.isEmpty ? 0 : row.width + spacing
            if !row.items.isEmpty, x + size.width > width {
                rows.append(row)
                y += row.height + spacing
                row = Row(y: y)
            }
            let start = row.items.isEmpty ? 0 : row.width + spacing
            row.items.append(Item(index: index, x: start, size: size))
            row.width = start + min(size.width, width)
            row.height = max(row.height, size.height)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

// MARK: - Page thumbnails

// a 3-across grid of page pictures with their page number
struct PageThumbnails: View {
    let images: [UIImage]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // two across at accessibility sizes so each page name fits on one line
        let across = typeSize.isAccessibilitySize ? 2 : 3
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: across), spacing: 12) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                VStack(spacing: 6) {
                    // a letter-shaped frame the page fills
                    Color.surface
                        .aspectRatio(8.5 / 11, contentMode: .fit)
                        .overlay { Image(uiImage: image).resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .strokeBorder(Color.hairline))
                        .accessibilityHidden(true)
                    Text("Page \(index + 1)")
                        .font(.body)
                        .foregroundStyle(Color.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(index + 1)")
            }
        }
    }
}

// a plain round mark in front of a row: a to-do tick or a pick-one choice
struct LeadingMark: ViewModifier {
    let symbol: String
    let isOn: Bool
    var onTone: Color = .accentInk
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 28

    func body(content: Content) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.9, weight: .regular))
                .foregroundStyle(isOn ? onTone : Color.ink3)
                .frame(width: size + 4, height: size + 4)
                .accessibilityHidden(true)
            content
        }
    }
}

extension View {
    func leadingMark(_ symbol: String, isOn: Bool, onTone: Color = .accentInk) -> some View {
        modifier(LeadingMark(symbol: symbol, isOn: isOn, onTone: onTone))
    }
}

// MARK: - Action tiles

// grey tiles side by side, icon over the word, all the same width, stacked at accessibility sizes
struct ActionTiles: View {
    struct Tile: Identifiable {
        let id: String
        let title: String
        let symbol: String
        var isDone = false
        let action: () -> Void
    }

    let tiles: [Tile]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 10) { ForEach(tiles) { tile($0) } }
        } else {
            HStack(spacing: 10) { ForEach(tiles) { tile($0) } }
        }
    }

    private func tile(_ tile: Tile) -> some View {
        Button(action: tile.action) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(HStackLayout(spacing: 10))
                                                      : AnyLayout(VStackLayout(spacing: 6))
            layout {
                Image(systemName: tile.symbol)
                    .font(.title3)
                    .foregroundStyle(Color.remedyTeal)
                    .accessibilityHidden(true)
                Text(tile.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(minHeight: Spacing.buttonHeight)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.surface2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(tile.isDone)
        .opacity(tile.isDone ? 0.6 : 1)
    }
}

// MARK: - Radio row

// a pick-one row, the round mark sits in the icon tile
struct RadioRow: View {
    let title: String
    var subtitle: String = ""
    let isOn: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ListRow(symbol: isOn ? "largecircle.fill.circle" : "circle", tone: isEnabled ? .info : .neutral,
                    title: title, subtitle: subtitle)
                .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// a pushed page with one text field, for a value read from the page
struct TextFieldPage: View {
    let title: String
    @Binding var text: String
    var prompt: String = ""
    var footer: String = ""

    var body: some View {
        List {
            Section {
                TextField(title, text: $text, prompt: Text(prompt))
                    .font(.body)
                    .frame(minHeight: Spacing.minTarget)
            } footer: {
                if !footer.isEmpty { Text(footer).font(.footnote).foregroundStyle(Color.ink2) }
            }
        }
        .remedyList()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
