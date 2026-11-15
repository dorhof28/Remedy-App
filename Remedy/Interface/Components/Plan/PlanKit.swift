//
//  PlanKit.swift
//  Remedy
//
//  shared plan pieces for both looks: instruction marks and topic cards, the quote sheet, the More grid tile, the day rows
//

import SwiftUI

// MARK: - Instruction mark

// filled check do, outlined cross avoid, outlined check fine, shape and colour both differ
struct InstructionMark: View {
    let kind: RuleReminders.Kind
    var large = false

    var body: some View {
        Image(systemName: kind.markSymbol)
            .font(large ? .title2 : .title3)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch kind {
        case .must: return .accentInk
        case .dont: return .cautionInk
        case .may: return .ink2
        }
    }
}

// MARK: - Topic tile

// the topic's own symbol on the instruction tile colours
struct TopicIconTile: View {
    let symbol: String
    var size: CGFloat = Spacing.iconTile

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Image(systemName: symbol)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(Color.infoInk)
            .frame(width: size * min(scale, 1.4), height: size * min(scale, 1.4))
            .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Color.infoSoft))
            .accessibilityHidden(true)
    }
}

// MARK: - One instruction line

// the mark, the plain sentence and when it ends, a tap shows the paper's words
struct InstructionLineRow: View {
    let row: ReminderRow
    var large = false
    let onQuote: (ReminderRow) -> Void

    var body: some View {
        Button { onQuote(row) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                InstructionMark(kind: row.kind, large: large)
                    .frame(width: large ? 34 : Spacing.iconTile)
                VStack(alignment: .leading, spacing: 2) {
                    Text(large ? SimpleWording.plain(row.text) : row.text)
                        .font(large ? .title3 : .body)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !row.detail.isEmpty {
                        Text(row.detail)
                            .font(large ? .body : .subheadline)
                            .foregroundStyle(Color.ink2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, large ? 12 : 10)
            .frame(minHeight: large ? Spacing.tapSimple : Spacing.tapMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenLabel)
        .accessibilityHint(row.quote.isEmpty ? "" : "Shows your paper's exact words")
        .disabled(row.quote.isEmpty)
    }
}

// MARK: - One topic card

// the topic's icon tile and title, then its lines with hairlines between
struct InstructionTopicCard: View {
    let group: ReminderTopicGroup
    var large = false
    let onQuote: (ReminderRow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                TopicIconTile(symbol: group.tileSymbol, size: large ? 48 : Spacing.iconTile)
                Text(group.title)
                    .font(large ? .title2.bold() : .headline)
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(group.spokenLabel)
            .accessibilityAddTraits(.isHeader)
            ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                        .padding(.leading, (large ? 34 : Spacing.iconTile) + 12)
                }
                InstructionLineRow(row: row, large: large, onQuote: onQuote)
            }
        }
        .padding(.horizontal, Spacing.insideCard)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Quote sheet

// the paper's exact words for one line, a sheet with a close circle and a tinted Done
struct PlanQuoteSheet: View {
    let title: String
    let quote: String
    var source: String = ""
    var large = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                    Text(title)
                        .font(large ? .title2.bold() : .title3.bold())
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\u{201C}\(quote)\u{201D}")
                        .font(large ? .title3 : .body)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Spacing.insideCard)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Color.surface2))
                    if !source.isEmpty {
                        Label(source, systemImage: "doc.text")
                            .font(large ? .body : .subheadline)
                            .foregroundStyle(Color.ink2)
                    }
                }
                .padding(Spacing.screenEdge)
            }
            .background(Color.surface)
            .navigationTitle("From your papers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetDoneButton(title: "Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Contact capsule

// call, text and email in one tinted capsule, each only when the papers have it
struct ContactCapsule: View {
    let name: String
    let phoneURL: URL?
    var messageURL: URL? = nil
    var mailURL: URL? = nil
    var large = false

    var body: some View {
        HStack(spacing: 0) {
            if let phoneURL { link(phoneURL, symbol: "phone", label: "Call \(name)") }
            if let messageURL { link(messageURL, symbol: "message", label: "Text \(name)") }
            if let mailURL { link(mailURL, symbol: "envelope", label: "Email \(name)") }
        }
        .background(Capsule().fill(Color.accentSoft))
    }

    private func link(_ url: URL, symbol: String, label: String) -> some View {
        Link(destination: url) {
            Image(systemName: symbol)
                .font(large ? .title3.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(Color.accentInk)
                .frame(width: large ? Spacing.tapSimple : Spacing.tapMin, height: large ? Spacing.tapSimple : Spacing.tapMin)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Day row

// the round check of a to-do, filled when done
struct TaskCheckMark: View {
    let isDone: Bool
    var large = false

    var body: some View {
        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
            .font(large ? .largeTitle : .title2)
            .foregroundStyle(isDone ? Color.accentInk : Color.ink3)
            .contentTransition(.symbolEffect(.replace))
            .frame(minWidth: large ? Spacing.tapSimple : Spacing.tapMin, minHeight: large ? Spacing.tapSimple : Spacing.tapMin)
            .accessibilityHidden(true)
    }
}

// MARK: - Simple row

// the simple look's big row: a bigger icon tile, plain words, its own card, at most one trailing control
struct SimplePlanRow<Trailing: View>: View {
    let kind: ItemKind
    let title: String
    var detail: String = ""
    var detailTone: Tone = .neutral
    var dimmed = false
    @ViewBuilder var trailing: Trailing

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                                  : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        layout {
            HStack(spacing: 14) {
                ItemIconTile(kind: kind, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(SimpleWording.plain(title))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(dimmed ? Color.ink2 : Color.ink)
                        .strikethrough(dimmed, color: .ink3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if !detail.isEmpty {
                        DetailLine(text: SimpleWording.plain(detail), tone: detailTone, font: .body)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            trailing
        }
        .padding(.horizontal, Spacing.insideCard)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: Spacing.tapSimple, alignment: .leading)
        .cardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension SimplePlanRow where Trailing == EmptyView {
    init(kind: ItemKind, title: String, detail: String = "", detailTone: Tone = .neutral, dimmed: Bool = false) {
        self.init(kind: kind, title: title, detail: detail, detailTone: detailTone, dimmed: dimmed) { EmptyView() }
    }
}

