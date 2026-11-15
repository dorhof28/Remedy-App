//
//  ToneKit.swift
//  Remedy
//
//  the one row pattern and the small pieces every screen shares, from the design reference
//

import SwiftUI

// MARK: - Item kinds
// four kinds of item, four icons, the same everywhere

// the kind of row, which sets its icon
enum ItemKind: Equatable {
    case medicine
    case asNeeded
    case paused
    case instruction
    case visit
    case todo
    case checkIn
    case goal(symbol: String)
    case surgery
    case paper
    case custom(symbol: String, tone: Tone)

    var symbol: String {
        switch self {
        case .medicine, .asNeeded: return "pill"
        case .paused: return "pause.circle"
        case .instruction: return "list.clipboard"
        case .visit: return "calendar"
        case .todo: return "checkmark.circle"
        case .checkIn: return "heart"
        case .goal(let symbol): return symbol
        case .surgery: return "cross.case"
        case .paper: return "doc.text"
        case .custom(let symbol, _): return symbol
        }
    }

    // tile fill behind the symbol
    var tile: Color {
        switch self {
        case .medicine, .goal: return .accentSoft
        case .asNeeded, .visit, .checkIn, .surgery: return .secondSoft
        case .paused: return .cautionSoft
        case .instruction: return .infoSoft
        case .todo, .paper: return .surface2
        case .custom(_, let tone): return tone.soft
        }
    }

    // symbol colour on the tile
    var ink: Color {
        switch self {
        case .medicine, .goal: return .accentInk
        case .asNeeded, .visit, .checkIn, .surgery: return .secondInk
        case .paused: return .cautionInk
        case .instruction: return .infoInk
        case .todo, .paper: return .ink2
        case .custom(_, let tone): return tone.color
        }
    }
}

extension Tone {
    // soft background for a tone
    var soft: Color {
        switch self {
        case .neutral: return .surface2
        case .good: return .goodSoft
        case .info: return .accentSoft
        case .caution: return .cautionSoft
        case .stop: return .dangerSoft
        }
    }
}

// MARK: - Icon tile

// 36pt rounded square with the kind's symbol, filled accent when it is the next thing
struct ItemIconTile: View {
    let kind: ItemKind
    var filled = false
    var size: CGFloat = Spacing.iconTile

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Image(systemName: kind.symbol)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(filled ? Color.onAccent : kind.ink)
            .frame(width: size * min(scale, 1.4), height: size * min(scale, 1.4))
            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .fill(filled ? Color.accentFill : kind.tile))
            .accessibilityHidden(true)
    }
}

// MARK: - The row

// icon tile, title, one second line, at most one trailing control
// rows grow with text and never cut it off, at large sizes the trailing control moves under
struct ItemRow<Trailing: View>: View {
    let kind: ItemKind
    let title: String
    var detail: String = ""
    var detailTone: Tone = .neutral
    var dimmed = false
    @ViewBuilder var trailing: Trailing

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                             : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            HStack(alignment: .center, spacing: 12) {
                ItemIconTile(kind: kind)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(dimmed ? Color.ink2 : Color.ink)
                        .strikethrough(dimmed, color: .ink3)
                        .fixedSize(horizontal: false, vertical: true)
                    if !detail.isEmpty {
                        DetailLine(text: detail, tone: detailTone)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            trailing
        }
        .padding(.vertical, 10)
        .frame(minHeight: Spacing.rowMin)
        .contentShape(Rectangle())
    }
}

extension ItemRow where Trailing == EmptyView {
    init(kind: ItemKind, title: String, detail: String = "", detailTone: Tone = .neutral, dimmed: Bool = false) {
        self.init(kind: kind, title: title, detail: detail, detailTone: detailTone, dimmed: dimmed) { EmptyView() }
    }
}

// MARK: - Grouped list card

// a white card holding rows with hairlines between them
struct GroupedCard<Content: View>: View {
    // one screen pixel, from the screen the card is on
    @Environment(\.pixelLength) private var pixel
    var padding: CGFloat = Spacing.insideCard
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.hairline)
                            .frame(height: pixel * 2)
                            .padding(.leading, Spacing.iconTile + 12)
                    }
                    row
                }
            }
        }
        .padding(.horizontal, padding)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Section header

// header above a card: a tinted symbol, headline ink title, the count in a small pill on the right
struct ListHeader: View {
    let title: String
    var trailing: String = ""
    var symbol: String = ""
    var tone: Tone = .info

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if !symbol.isEmpty {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone == .neutral ? Color.ink2 : tone.color)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            if !trailing.isEmpty {
                if trailing.count <= 14 {
                    CountPill(text: trailing, tone: tone == .info ? .neutral : tone)
                } else {
                    Text(trailing).font(.subheadline).foregroundStyle(Color.ink2)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, Spacing.sectionGap - Spacing.betweenCards)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Badges

// small pill: a taken time, a count, SAMPLE
struct StatusBadge: View {
    let text: String
    var symbol: String = ""
    var tone: Tone = .good

    var body: some View {
        HStack(spacing: 4) {
            if !symbol.isEmpty { Image(systemName: symbol).font(.caption.weight(.bold)) }
            Text(text).font(.footnote.weight(.semibold)).monospacedDigit()
        }
        .foregroundStyle(tone == .neutral ? Color.ink2 : tone.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tone.soft))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Source row

// "From your discharge paper", the doctor and date, opens the exact quote
struct SourceRow: View {
    let title: String
    var detail: String = ""
    var action: (() -> Void)? = nil

    var body: some View {
        let row = HStack(spacing: 12) {
            ItemIconTile(kind: .paper)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Color.ink)
                if !detail.isEmpty {
                    Text(detail).font(.subheadline).foregroundStyle(Color.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if action != nil { Chevron() }
        }
        .padding(.horizontal, Spacing.insideCard)
        .padding(.vertical, 12)
        .frame(minHeight: Spacing.rowMin)
        .cardStyle()

        if let action {
            Button(action: action) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

// MARK: - Eyebrow

// the only uppercase text in the app: NEXT · 2:00 PM
struct Eyebrow: View {
    let text: String
    var tone: Tone = .info
    var symbol: String = ""

    var body: some View {
        HStack(spacing: 4) {
            if !symbol.isEmpty { Image(systemName: symbol) }
            Text(text.uppercased())
        }
        .font(.caption.weight(.bold))
        .tracking(0.4)
        .foregroundStyle(tone == .neutral ? Color.ink2 : tone.color)
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.betweenCards) {
            ListHeader(title: "Today, Tuesday", trailing: "2 of 5 done")
            GroupedCard {
                ItemRow(kind: .todo, title: "Buy a shower chair", detail: "By 4:00 PM")
                ItemRow(kind: .medicine, title: "Eliquis 5 mg", detail: "8:00 PM · 1 tablet")
                ItemRow(kind: .medicine, title: "Tylenol 500 mg", detail: "8:00 AM") {
                    StatusBadge(text: "8:03", symbol: "checkmark")
                }
            }
            SourceRow(title: "From your discharge paper", detail: "Dr. Rao · printed Nov 19") {}
            Eyebrow(text: "Next · 2:00 PM")
        }
        .padding()
    }
    .remedyBackground()
}
